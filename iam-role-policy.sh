#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration Variables - PLEASE EDIT THESE ---
JENKINS_EC2_INSTANCE_ID="i-0b59a091a868aa50c" # Your Jenkins EC2 Instance ID
NEW_IAM_ROLE_NAME="JenkinsEC2InstanceRoleV2"  # Choose a unique name for the new IAM role
INSTANCE_PROFILE_NAME="${NEW_IAM_ROLE_NAME}-Profile" # Name for the instance profile
SECRETS_POLICY_NAME="JenkinsEC2SecretsAccessPolicyV2" # Choose a unique name for the policy
# Replace with the FULL ARN of the secret you created in AWS Secrets Manager
# Example: arn:aws:secretsmanager:us-east-1:123456789012:secret:devops_project/jenkins/api_key-aBcDeF
SECRET_ARN_TO_ACCESS="arn:aws:secretsmanager:us-east-1:905418222266:secret:devops_project/jenkins/api_key-KwBNJi"
AWS_REGION="us-east-1" # Your AWS Region

# --- Helper Function for Section Headers ---
echo_step() {
    echo ""
    echo "----------------------------------------"
    echo "$1"
    echo "----------------------------------------"
}

# --- 1. Create Trust Policy JSON for EC2 Role ---
echo_step "Creating trust policy document for EC2..."
TRUST_POLICY_JSON_FILE="ec2-trust-policy.json"
cat > "$TRUST_POLICY_JSON_FILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
echo "Trust policy written to ${TRUST_POLICY_JSON_FILE}"

# --- 2. Create IAM Role ---
echo_step "Creating IAM Role: ${NEW_IAM_ROLE_NAME}..."
ROLE_CREATE_OUTPUT=$(aws iam create-role \
    --role-name "${NEW_IAM_ROLE_NAME}" \
    --assume-role-policy-document file://"${TRUST_POLICY_JSON_FILE}" \
    --description "IAM role for Jenkins EC2 instance to access AWS services" \
    --region "${AWS_REGION}" 2>&1) # Capture stderr too

if echo "${ROLE_CREATE_OUTPUT}" | grep -q "EntityAlreadyExists"; then
    echo "IAM Role '${NEW_IAM_ROLE_NAME}' already exists. Skipping creation."
    # Optionally, you could fetch the existing role ARN here if needed for subsequent steps
    # For now, we assume if it exists, it's usable.
else
    # Check if output contains an ARN, indicating success
    if ! echo "${ROLE_CREATE_OUTPUT}" | grep -q '"Arn":'; then
        echo "ERROR: Failed to create IAM Role."
        echo "${ROLE_CREATE_OUTPUT}"
        rm -f "$TRUST_POLICY_JSON_FILE" # Clean up
        exit 1
    fi
    echo "IAM Role '${NEW_IAM_ROLE_NAME}' created successfully."
    echo "${ROLE_CREATE_OUTPUT}"
fi
CREATED_ROLE_ARN=$(aws iam get-role --role-name "${NEW_IAM_ROLE_NAME}" --query "Role.Arn" --output text --region "${AWS_REGION}")
echo "Role ARN: ${CREATED_ROLE_ARN}"


# --- 3. Create Instance Profile ---
echo_step "Creating Instance Profile: ${INSTANCE_PROFILE_NAME}..."
INSTANCE_PROFILE_CREATE_OUTPUT=$(aws iam create-instance-profile \
    --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
    --region "${AWS_REGION}" 2>&1)

if echo "${INSTANCE_PROFILE_CREATE_OUTPUT}" | grep -q "EntityAlreadyExists"; then
    echo "Instance Profile '${INSTANCE_PROFILE_NAME}' already exists. Skipping creation."
else
    if ! echo "${INSTANCE_PROFILE_CREATE_OUTPUT}" | grep -q '"Arn":'; then
        echo "ERROR: Failed to create Instance Profile."
        echo "${INSTANCE_PROFILE_CREATE_OUTPUT}"
        rm -f "$TRUST_POLICY_JSON_FILE" # Clean up
        exit 1
    fi
    echo "Instance Profile '${INSTANCE_PROFILE_NAME}' created successfully."
    echo "${INSTANCE_PROFILE_CREATE_OUTPUT}"
fi

# --- 4. Add Role to Instance Profile ---
echo_step "Adding Role '${NEW_IAM_ROLE_NAME}' to Instance Profile '${INSTANCE_PROFILE_NAME}'..."
# Check if role is already added to prevent error
EXISTING_ROLES_IN_PROFILE=$(aws iam get-instance-profile --instance-profile-name "${INSTANCE_PROFILE_NAME}" --query "InstanceProfile.Roles[?RoleName=='${NEW_IAM_ROLE_NAME}']" --output text --region "${AWS_REGION}")
if [ -n "$EXISTING_ROLES_IN_PROFILE" ]; then
    echo "Role '${NEW_IAM_ROLE_NAME}' is already associated with Instance Profile '${INSTANCE_PROFILE_NAME}'. Skipping."
else
    aws iam add-role-to-instance-profile \
        --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
        --role-name "${NEW_IAM_ROLE_NAME}" \
        --region "${AWS_REGION}"
    echo "Role added to Instance Profile."
fi

# --- 5. Associate Instance Profile with EC2 Instance ---
echo_step "Associating Instance Profile '${INSTANCE_PROFILE_NAME}' with EC2 Instance '${JENKINS_EC2_INSTANCE_ID}'..."
# Check if an instance profile is already associated
CURRENT_ASSOCIATION=$(aws ec2 describe-iam-instance-profile-associations \
    --filters "Name=instance-id,Values=${JENKINS_EC2_INSTANCE_ID}" \
    --query "IamInstanceProfileAssociations[0].AssociationId" --output text --region "${AWS_REGION}")

if [ "$CURRENT_ASSOCIATION" != "None" ] && [ -n "$CURRENT_ASSOCIATION" ]; then
    echo "Instance '${JENKINS_EC2_INSTANCE_ID}' already has an IAM instance profile association (${CURRENT_ASSOCIATION}). Replacing it."
    aws ec2 replace-iam-instance-profile-association \
        --iam-instance-profile Name="${INSTANCE_PROFILE_NAME}" \
        --association-id "${CURRENT_ASSOCIATION}" \
        --region "${AWS_REGION}"
else
    aws ec2 associate-iam-instance-profile \
        --instance-id "${JENKINS_EC2_INSTANCE_ID}" \
        --iam-instance-profile Name="${INSTANCE_PROFILE_NAME}" \
        --region "${AWS_REGION}"
fi
echo "Instance Profile associated with EC2 instance. Changes may take a few moments to propagate."
# It's good to wait a bit for the association to take effect before attaching policies that rely on the role being fully usable by the instance
sleep 15 

# --- 6. Create Secrets Access Policy JSON ---
echo_step "Creating secrets access policy document..."
SECRETS_POLICY_JSON_FILE="jenkins-ec2-secrets-policy.json"
cat > "$SECRETS_POLICY_JSON_FILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "${SECRET_ARN_TO_ACCESS}"
    }
  ]
}
EOF
echo "Secrets access policy written to ${SECRETS_POLICY_JSON_FILE}"

# --- 7. Create IAM Policy for Secrets Access ---
echo_step "Creating IAM Policy: ${SECRETS_POLICY_NAME}..."
POLICY_CREATE_OUTPUT=$(aws iam create-policy \
    --policy-name "${SECRETS_POLICY_NAME}" \
    --policy-document file://"${SECRETS_POLICY_JSON_FILE}" \
    --description "Allows the Jenkins EC2 role to read a specific secret from Secrets Manager" \
    2>&1)

if echo "${POLICY_CREATE_OUTPUT}" | grep -q "EntityAlreadyExists"; then
    echo "IAM Policy '${SECRETS_POLICY_NAME}' already exists. Skipping creation."
    # Construct the ARN for an existing policy (assuming default path)
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    CREATED_POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${SECRETS_POLICY_NAME}"
else
    if ! echo "${POLICY_CREATE_OUTPUT}" | grep -q '"Arn":'; then
        echo "ERROR: Failed to create IAM Policy for secrets access."
        echo "${POLICY_CREATE_OUTPUT}"
        rm -f "$TRUST_POLICY_JSON_FILE" "$SECRETS_POLICY_JSON_FILE" # Clean up
        exit 1
    fi
    echo "IAM Policy '${SECRETS_POLICY_NAME}' created successfully."
    echo "${POLICY_CREATE_OUTPUT}"
    CREATED_POLICY_ARN=$(echo "${POLICY_CREATE_OUTPUT}" | grep '"Arn":' | awk -F'"' '{print $4}')
fi
echo "Policy ARN: ${CREATED_POLICY_ARN}"


# --- 8. Attach Secrets Access Policy to the Role ---
echo_step "Attaching Policy '${SECRETS_POLICY_NAME}' to Role '${NEW_IAM_ROLE_NAME}'..."
aws iam attach-role-policy \
    --role-name "${NEW_IAM_ROLE_NAME}" \
    --policy-arn "${CREATED_POLICY_ARN}" \
    --region "${AWS_REGION}"
echo "Policy attached to role."

# --- 9. Clean up local JSON files ---
echo_step "Cleaning up temporary JSON files..."
rm -f "$TRUST_POLICY_JSON_FILE" "$SECRETS_POLICY_JSON_FILE"
echo "Cleanup complete."

echo_step "Automation Complete!"
echo "IAM Role '${NEW_IAM_ROLE_NAME}' (ARN: ${CREATED_ROLE_ARN}) has been created."
echo "Instance Profile '${INSTANCE_PROFILE_NAME}' has been associated with EC2 instance '${JENKINS_EC2_INSTANCE_ID}'."
echo "Policy '${SECRETS_POLICY_NAME}' (ARN: ${CREATED_POLICY_ARN}) granting access to secret '${SECRET_ARN_TO_ACCESS}' has been attached to the role."
echo "It might take a few moments for IAM changes to fully propagate across AWS."
