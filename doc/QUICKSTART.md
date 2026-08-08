# 5-Minute Quick Start with Docker

This guide will help you launch the Xiandao game server in under 5 minutes using Docker.

## Prerequisites

- **Docker** & **Docker Compose** installed
- **8GB RAM** recommended (6GB minimum)
- **Ports** 13800, 8888, 9001, 8443 available
- **MySQL** running on host (optional, see configuration below)

## Quick Start

### 1. Prepare Data Directories

```bash
# Create data directories
mkdir -p /usr/local/games/allxd/xd01/data_xiand
mkdir -p /usr/local/games/allxd/xd01/item
mkdir -p /usr/local/games/allxd/log/xd01
```

### 2. Configure Environment

```bash
cd /usr/local/games/xiand/docker

# Create .env file with your configuration
cat > .env << EOF
# Game instance
GAME_AREA=xd01

# Ports
MUD_PORT=13800
HTTP_API_PORT=8888
TOMCAT_HTTP_PORT=9001
TOMCAT_HTTPS_PORT=8443

# MySQL Configuration (REQUIRED)
MYSQL_HOST=172.17.0.1
MYSQL_PORT=3306
MYSQL_USER=xiandao
MYSQL_PASSWORD=your_mysql_password_here
EOF
```

**Important:** Replace `your_mysql_password_here` with your actual MySQL password.

### 3. Launch the Server

```bash
# Pull and start the container
docker-compose up -d

# Check logs
docker-compose logs -f xiand
```

### 4. Access the Game

| Service | URL | Description |
|---------|-----|-------------|
| **Web Interface** | http://localhost:9001 | Main game portal |
| **HTTP API** | http://localhost:8888 | API endpoint |
| **MUD Port** | localhost:13800 | Direct MUD connection |

## Configuration

### MySQL Setup

#### Step 1: Initialize Database

Run the MySQL initialization script:

```bash
# Import the schema
mysql -u root -p < doc/mysql-init.sql

# Or from MySQL prompt
mysql -u root -p
mysql> source /path/to/doc/mysql-init.sql;
```

This creates:
- Database `xd01` with UTF-8 support
- All required tables
- Docker user `xiandao` with a password supplied outside the repository

#### Step 2: Configure Environment Variables

Create `.env` file in `docker/` directory:

```bash
MYSQL_HOST=172.17.0.1
MYSQL_PORT=3306
MYSQL_USER=xiandao
MYSQL_PASSWORD=<set-a-strong-secret>
```

**Security Note:** keep the real password only in a mode-600 `.env` or secret manager.

### Multiple Game Instances

```bash
# Game instance 2
GAME_AREA=xd02 MUD_PORT=13801 docker-compose up -d

# Game instance 3
GAME_AREA=xd03 MUD_PORT=13802 docker-compose up -d
```

## Troubleshooting

### Container won't start?

```bash
# Check logs
docker-compose logs xiand

# Check resource limits
docker stats
```

### Port already in use?

Change ports in `.env`:
```bash
MUD_PORT=13800  # Change to available port
HTTP_API_PORT=8888
```

### Permission issues with data directories?

```bash
# Fix directory permissions
sudo chown -R $USER:$USER /usr/local/games/allxd
```

## Next Steps

- Read [README.txt](../README.txt) for detailed configuration
- Visit [GitHub Discussions](https://github.com/lijingmt/xd/discussions) for community support
- Check the [Project Documentation](https://github.com/lijingmt/xd/wiki) for advanced setup

## License

MIT License - See [LICENSE](../LICENSE) for details.
