#include "codexion.h"


int	check_arg_size(int argc)
{
	if (argc < 9)
	{
		fprintf(stderr, "Missing arguments! You have %d, you need 8\n",
			argc - 1);
		return (0);
	}
	else if (argc > 9)
	{
		fprintf(stderr, "Too many arguments! You have %d, you need 8\n",
			argc - 1);
		return (0);
	}
	return (1);
}

int	is_only_digits(char *str)
{
	int	i;

	if (str[0] == '\0')
		return (0);
	i = 0;
	while (str[i] != '\0')
	{
		if (str[i] < '0' || str[i] > '9')
			return (0);
		i++;
	}
	return (1);
}

int	print_error(char *message, char *arg)
{
	fprintf(stderr, "Error: %s: \"%s\"\n", message, arg);
	return (0);
}

int	fits_in_int(char *str)
{
	long	result;
	int		i;

	result = 0;
	i = 0;
	while (str[i] != '\0')
	{
		result = result * 10 + (str[i] - '0');
		if (result > INT_MAX)
			return (0);
		i++;
	}
	return (1);
}