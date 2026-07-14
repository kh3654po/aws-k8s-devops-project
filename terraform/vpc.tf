module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.prefix}-vpc"
  cidr = "10.0.0.0/16"

  # 가용 영역과 서브넷 설정
  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # 각 서브넷에 사용할 이름을 명시 (리스트 길이는 서브넷 수와 동일해야 함)
  public_subnet_names = [
    "${var.prefix}-public-1",
    "${var.prefix}-public-2",
  ]

  private_subnet_names = [
    "${var.prefix}-private-1",
    "${var.prefix}-private-2",
  ]

  # 퍼블릭 서브넷과 프라이빗 서브넷에 Kubernetes 클러스터 관련 태그를 추가하여, AWS Load Balancer Controller가 해당 서브넷을 인식하도록 설정
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  # 각 가용 영역마다 NAT Gateway를 생성하여 고가용성을 확보
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # 퍼블릭 서브넷에서 자동으로 퍼블릭 IP 할당
  map_public_ip_on_launch = true

  # 퍼블릭 라우트 테이블을 하나만 생성하여 모든 퍼블릭 서브넷이 공유하도록 설정 (기본값 false) 만약 각 퍼블릭 서브넷마다 별도의 라우트 테이블을 생성하려면 true로 설정
  create_multiple_public_route_tables = false

  # tags는 VPC와 서브넷, 라우트 테이블 등 모든 리소스에 공통으로 적용할 태그를 지정하는데 사용. 
  tags = {}

  # vpc_tags는 VPC 자체에 붙일 태그를 지정하는데 사용. 
  vpc_tags = {
    "Name" = "${var.prefix}-vpc"
  }
}