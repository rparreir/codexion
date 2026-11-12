NAME	= codexion

CC		= cc
# -I include: o compilador procura o codexion.h na pasta include/
CFLAGS	= -Wall -Wextra -Werror -pthread -I include

# os .c do projeto, por pasta:
# parsing/ (fase 1) · simulation/ (fases 2 e 3) · dongles/ (fases 4 e 5)
SRCS	= src/main.c \
		  src/parsing/parsing.c \
		  src/parsing/parsing_helpers.c \
		  src/simulation/coder.c \
		  src/simulation/monitor.c \
		  src/simulation/sim.c \
		  src/simulation/sync.c \
		  src/simulation/time.c \
		  src/dongles/dongle.c \
		  src/dongles/queue.c \
		  src/dongles/scheduler.c

# cada .o fica ao lado do seu .c
OBJS	= $(SRCS:.c=.o)

HEADER	= include/codexion.h

all: $(NAME)

# só volta a linkar se algum .o for mais recente que o executável
$(NAME): $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o $(NAME)

# cada .o depende do seu .c e do header: mudar o header recompila tudo
%.o: %.c $(HEADER)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS)

fclean: clean
	rm -f $(NAME)

re: fclean all

# testes automáticos: PASS/FAIL de cada teste e um resumo no fim
test: $(NAME)
	bash tests.sh

.PHONY: all clean fclean re test
