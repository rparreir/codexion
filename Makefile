NAME	= codexion

CC		= cc
CFLAGS	= -Wall -Wextra -Werror -pthread

# os .c do projeto (debug.c é temporário)
SRCS	= main.c \
		  parsing.c \
		  parsing_helpers.c \
		  debug.c \
		  time.c \
		  sim.c

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

.PHONY: all clean fclean re
