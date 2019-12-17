#! /bin/bash
# Redirect all output with -> exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

sudo yum update -y
sudo yum install mysql docker git tree -y
sudo systemctl enable docker
sudo systemctl start docker

# Placing the certificate to login to the servers in the private subnet
aws ssm get-parameter --name Work.pem --region eu-west-1 --with-decryption | jq -r .Parameter.Value | tee /root/Work.pem /home/ec2-user/Work.pem >/dev/null
chmod 600 /root/Work.pem /home/ec2-user/Work.pem