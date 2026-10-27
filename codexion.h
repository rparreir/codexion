#ifndef CODEXION_H
# define CODEXION_H

# include <stdio.h>
# include <stdlib.h>
# include <string.h>
# include <limits.h>
# include <time.h>
# include <unistd.h>
# include <pthread.h>



typedef struct s_config
{
	int		number_of_coders;
	long	time_to_burnout;
	long	time_to_compile;
	long	time_to_debug;
	long	time_to_refactor;
	int		number_of_compiles_required;
	long	dongle_cooldown;
	int		scheduler; /* 0 = fifo, 1 = edf */
}	t_config;

/* declaração antecipada: o t_coder aponta para a t_sim, e a t_sim tem os coders */
typedef struct s_sim	t_sim;

typedef struct s_coder
{
	int			id;
	long		burnout_deadline;
	int			compiles_done;
	pthread_t	thread;
	t_sim		*shared;
}	t_coder;

struct s_sim
{
	t_config		config;
	long			start_time;
	pthread_mutex_t	log_mutex;
	t_coder			*coders;
};

/* protótipos, agrupados pelo ficheiro .c onde a função está */
	int		check_arg_size(int argc);
    int     is_only_digits(char *str);
	int		fits_in_int(char *str);
	int		print_error(char *message, char *arg);
	int		parsing_validation(int argc, char **argv);
	void	fill_config(char **argv, t_config *config);
	long	get_time_ms(void);
	long	elapsed_ms(long start);
	void	precise_sleep(long ms);
	void	init_coders(t_sim *sim);
	int		init_sim(t_sim *sim, t_config *config);
	void	free_sim(t_sim *sim);
/* debug.c (temporário) */
void	print_config(t_config *config);
void	print_coders(t_sim *sim);
#endif