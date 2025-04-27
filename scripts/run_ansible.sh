#!/bin/bash

echo "Checking Jenkins VM SSH availability..."

# Wait for SSH to be ready
until ssh -o StrictHostKeyChecking=no -i ~/.ssh/terraform-key ubuntu@$(awk '/^[0-9]/ {print $1}' ansible/inventory.ini) 'echo SSH is up'; do
  echo "Waiting for SSH..."
  sleep 5
done

echo "Running Ansible playbook..."
ansible-playbook -i ansible/inventory.ini ansible/install_jenkins.yml

