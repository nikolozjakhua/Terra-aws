variable subnets {
    type = object({
        public_a = string
        public_b = string
        public_c = string
    })
}

variable db_subnets {
    type = object({
        private_db_a = string
        private_db_b = string
        private_db_c = string
    })
}

variable private_subnets {
    type = object({
        private_a = string
        private_b = string
        private_c = string
    })
}

variable zones {
    type = object({
        avail_zone_a = string
        avail_zone_b = string
        avail_zone_c = string
    })
}

variable vpc_cidr_block {}
variable my_ip {}
variable public_key_location {}
variable db_user {}
variable aws_region {}
variable ECR_IMAGE {}