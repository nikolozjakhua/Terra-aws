subnets = {
    public_a = "10.10.1.0/24"
    public_b = "10.10.2.0/24"
    public_c = "10.10.3.0/24"
}

db_subnets = {
    private_db_a = "10.10.20.0/24"
    private_db_b = "10.10.21.0/24"
    private_db_c = "10.10.22.0/24"
}

private_subnets = {
    private_a = "10.10.10.0/24"
    private_b = "10.10.11.0/24"
    private_c = "10.10.12.0/24"
}

zones = {
    avail_zone_a = "eu-central-1a"
    avail_zone_b = "eu-central-1b"
    avail_zone_c = "eu-central-1c"
}

vpc_cidr_block = "10.10.0.0/16"
my_ip = "213.157.206.250/32"
public_key_location = "~/.ssh/id_rsa.pub"
db_user = "nikoloz"
aws_region = "eu-central-1"
ECR_IMAGE = "106164528568.dkr.ecr.eu-central-1.amazonaws.com/ghost:4.12.1"