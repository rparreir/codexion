#include "codexion.h"

int	parsing_validation(int argc, char **argv)
{
	int	i;

	if (!check_arg_size(argc))
		return (0);
	i = 1;
	while (i < argc - 1)
	{
		if (!is_only_digits(argv[i]))
			return (print_error("argument must contain only digits", argv[i]));
		if (!fits_in_int(argv[i]))
			return (print_error("argument is bigger than INT_MAX", argv[i]));
		i++;
	}
	if (atoi(argv[1]) < 1)
		return (print_error("number_of_coders must be at least 1", argv[1]));
	if (strcmp(argv[8], "fifo") != 0 && strcmp(argv[8], "edf") != 0)
		return (print_error("scheduler must be \"fifo\" or \"edf\"", argv[8]));
	return (1);
}

void	fill_config(char **argv, t_config *config)
{
	config->number_of_coders = atoi(argv[1]);
	config->time_to_burnout = atoi(argv[2]);
	config->time_to_compile = atoi(argv[3]);
	config->time_to_debug = atoi(argv[4]);
	config->time_to_refactor = atoi(argv[5]);
	config->number_of_compiles_required = atoi(argv[6]);
	config->dongle_cooldown = atoi(argv[7]);
	if (strcmp(argv[8], "fifo") == 0)
		config->scheduler = 0;
	else
		config->scheduler = 1;
}
