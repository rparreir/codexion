NAME	= codexion

CC		= cc
CFLAGS	= -Wall -Wextra -Werror -pthread

# os .c do projeto
SRCS	= main.c \
		  parsing.c \
		  parsing_helpers.c \
		  time.c \
		  sim.c \
		  coder.c \
		  monitor.c \
		  sync.c \
		  dongle.c \
		  scheduler.c \
		  queue.c

OBJS	= $(SRCS:.c=.o)

HEADER	= codexion.h

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
