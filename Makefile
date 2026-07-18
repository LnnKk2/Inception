NAME = inception
COMPOSE_FILE = srcs/docker-compose.yml
COMPOSE = docker compose -p $(NAME) -f $(COMPOSE_FILE)
DATA = /home/aandreo42/data

.PHONY: all up build down clean fclean re ps

all: up

up:
	mkdir -p $(DATA)/mariadb $(DATA)/wordpress
	$(COMPOSE) up -d --build

build:
	$(COMPOSE) build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --remove-orphans

fclean:
	$(COMPOSE) down -v --remove-orphans --rmi all
	sudo rm -rf $(DATA)/mariadb $(DATA)/wordpress

re: fclean up

ps:
	$(COMPOSE) ps
