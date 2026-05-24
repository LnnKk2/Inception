NAME = inception
COMPOSE_FILE = srcs/docker-compose.yml
COMPOSE = docker-compose -p $(NAME) -f $(COMPOSE_FILE)

.PHONY: all up build down clean fclean re ps

all: up

up:
	$(COMPOSE) up -d --build

build:
	$(COMPOSE) build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --remove-orphans

fclean:
	$(COMPOSE) down -v --remove-orphans --rmi all

re: fclean up

ps:
	$(COMPOSE) ps
