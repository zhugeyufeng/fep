#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker未安装，正在安装...${NC}"
        curl -fsSL https://get.docker.com | sh
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}Docker Compose未安装，正在安装...${NC}"
        curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
}

# 部署中心节点
deploy_master() {
    echo -e "${GREEN}开始部署中心节点...${NC}"
    
    # 创建必要目录
    mkdir -p /opt/asn-master
    cd /opt/asn-master
    
    # 创建 docker-compose.yml
    cat > docker-compose.yml << 'EOF'
    version: '3.8'
    
    services:
      web-master:
        build: 
          context: .
          dockerfile: Dockerfile
        ports:
          - "80:8000"
        environment:
          - NODE_ROLE=master
          - NODE_NAME=master.asn.local
          - MASTER_URL=main.curl.im
          - DATABASE_URL=mysql+pymysql://user:password@db/asn_scanner
          - REDIS_URL=redis://redis:6379/0
          - SECRET_KEY=${SECRET_KEY}
        depends_on:
          - db
          - redis
        restart: always
    
      db:
        image: mysql:8.0
        environment:
          - MYSQL_DATABASE=asn_scanner
          - MYSQL_USER=user
          - MYSQL_PASSWORD=password
          - MYSQL_ROOT_PASSWORD=rootpassword
        volumes:
          - mysql_data:/var/lib/mysql
        restart: always
    
      redis:
        image: redis:6.2-alpine
        restart: always
    
    volumes:
      mysql_data:
    EOF
    
    # 配置环境变量
    if [ ! -f .env ]; then
        echo "SECRET_KEY=$(openssl rand -hex 32)" > .env
        echo -e "${YELLOW}已生成随机SECRET_KEY${NC}"
    fi
    
    # 创建 Dockerfile
    cat > Dockerfile << 'EOF'
    FROM python:3.9-slim
    
    WORKDIR /app
    
    RUN apt-get update && apt-get install -y \
        gcc \
        libpq-dev \
        && rm -rf /var/lib/apt/lists/*
    
    COPY requirements.txt .
    RUN pip install --no-cache-dir -r requirements.txt
    
    COPY . .
    
    ENV PYTHONPATH=/app
    ENV PYTHONUNBUFFERED=1
    
    EXPOSE 8000
    
    CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
    EOF
    
    # 复制必要文件
    mkdir -p {api,models,scanner,utils}
    
    # 启动服务
    docker-compose up -d
    
    # 等待服务启动
    echo -e "${YELLOW}等待服务启动...${NC}"
    sleep 10
    
    # 初始化数据库
    docker-compose exec -T web-master alembic upgrade head
    
    echo -e "${GREEN}中心节点部署完成！${NC}"
    echo -e "请确保域名 main.curl.im 已正确解析到本服务器IP"
    echo -e "可以通过访问 http://main.curl.im/health 检查服务状态"
}

# 部署扫描节点
deploy_scanner() {
    echo -e "${GREEN}开始部署扫描节点...${NC}"
    
    # 获取Worker ID
    read -p "请输入扫描节点ID (1-999): " worker_id
    if ! [[ "$worker_id" =~ ^[0-9]+$ ]] || [ "$worker_id" -lt 1 ] || [ "$worker_id" -gt 999 ]; then
        echo -e "${RED}错误：节点ID必须是1-999之间的数字${NC}"
        exit 1
    fi
    
    # 创建必要目录
    mkdir -p /opt/asn-scanner-$worker_id
    cd /opt/asn-scanner-$worker_id
    
    # 创建 docker-compose.yml
    cat > docker-compose.yml << 'EOF'
    version: '3.8'
    
    services:
      scanner:
        build:
          context: .
          dockerfile: Dockerfile.scanner
        environment:
          - NODE_ROLE=worker
          - WORKER_ID=${WORKER_ID:-1}
          - MASTER_URL=main.curl.im
        restart: always
    EOF
    
    # 创建 Dockerfile.scanner
    cat > Dockerfile.scanner << 'EOF'
    FROM python:3.9-slim
    
    WORKDIR /app
    
    RUN apt-get update && apt-get install -y \
        gcc \
        libpq-dev \
        nmap \
        masscan \
        && rm -rf /var/lib/apt/lists/*
    
    COPY requirements.scanner.txt requirements.txt
    RUN pip install --no-cache-dir -r requirements.txt
    
    COPY scanner/ scanner/
    COPY utils/ utils/
    COPY config.py .
    
    CMD ["python", "-m", "scanner.worker"]
    EOF
    
    # 配置环境变量
    echo "WORKER_ID=$worker_id" > .env
    
    # 创建必要目录和文件
    mkdir -p {scanner,utils}
    
    # 启动服务
    docker-compose up -d
    
    echo -e "${GREEN}扫描节点 $worker_id 部署完成！${NC}"
    echo -e "可以通过以下命令查看日志："
    echo -e "docker-compose logs -f scanner"
}

# 主菜单
main_menu() {
    clear
    echo -e "${GREEN}ASN扫描系统部署脚本${NC}"
    echo "------------------------"
    echo "1. 部署中心节点"
    echo "2. 部署扫描节点"
    echo "3. 退出"
    echo "------------------------"
    read -p "请选择要部署的节点类型 [1-3]: " choice
    
    case $choice in
        1)
            deploy_master
            ;;
        2)
            deploy_scanner
            ;;
        3)
            echo -e "${YELLOW}退出脚本${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效的选择${NC}"
            exit 1
            ;;
    esac
}

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用root用户运行此脚本${NC}"
    exit 1
fi

# 检查必要的命令
check_docker

# 运行主菜单
main_menu 