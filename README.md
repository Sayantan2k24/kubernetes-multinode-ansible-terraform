# kubernetes-multinode-ansible-terraform
We are setting up the Multi Node K8s Cluster on AWS EC2 instances using Terraform and Ansible Automation Tool.

## Diagram
![Screenshot (8792)](https://github.com/Sayantan2k24/kubernetes-multinode-ansible-terraform/assets/90416470/77d5fe63-2635-41f3-9c7a-a87efc813de6)

## Tools Used
1. Terraform
2. Ansible
3. AWS
4. Rhel 9 OS
5. Kubeadm
6. CRI-O 
7. Kubectl
8. Calico CNI
and more..
   
## Overview
### terraform-ws:

1. **VPC Setup:**
   - Creates a default VPC with a tag "Default VPC".

2. **Subnet Setup:**
   - Retrieves availability zones for the selected region.
   - Creates a default subnet in the first availability zone with a tag indicating its availability zone.

3. **Security Group Setup:**
   - Creates a security group named "secure-sg" with various ingress and egress rules for different services like SMTP, HTTP, HTTPS, SSH, Kubernetes API server, NodePort services, and ICMP.
   - Attaches the security group to instances later in the configuration.

4. **SSH Key Pair Setup:**
   - Creates an SSH key pair named "id_rsa" to be used for accessing EC2 instances.

5. **EC2 Instance Setup - Kubernetes Master:**
   - Launches an EC2 instance for the Kubernetes master node.
   - Associates it with the default subnet and security group.
   - Uses the SSH key pair for authentication.
   - Tags the instance as "k8s-master".

6. **EC2 Instance Setup - Kubernetes Slaves:**
   - Launches two EC2 instances for Kubernetes slave nodes using a count loop.
   - Associates them with the default subnet and security group.
   - Uses the same SSH key pair for authentication.
   - Tags the instances as "k8s-slave-1" and "k8s-slave-2".

7. **Outputs:**
   - Retrieves the public IP addresses of the master and slave nodes and outputs them.

8. **Ansible Configuration:**
   - Generates Ansible inventory dynamically with the public IPs of master and slave nodes.
   - Configures Ansible settings like host key checking, inventory file location, remote user, private key file, etc., in the ansible.cfg file.

9. **Trigger Ansible Playbooks:**
   - Triggers two Ansible playbook runs: one for common configurations (`rhel_common.yml`) and another for master-specific configurations (`rhel_master.yml`).
   - Dependencies ensure that Ansible is run after the EC2 instances are created and the Ansible configuration files are generated.

### ansible-ws
Check the link to know further

https://github.com/Sayantan2k24/kubernetes-multinode-ansible-aws.git
