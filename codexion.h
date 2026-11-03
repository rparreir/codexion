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

/* declaração antecipada: o t_coder aponta para a t_sim,
   e a t_sim tem os coders */
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
	int				simulation_over;
	pthread_mutex_t	log_mutex;
	pthread_mutex_t	stop_mutex;
	t_coder			*coders;
	pthread_t		monitor;
	int				started;
	pthread_cond_t	start_cond;
	int				ready;
};

/* protótipos das funções usadas fora do seu ficheiro; as funções locais
   (só usadas dentro do próprio .c) não estão aqui */

/* parsing_helpers.c — validação de cada argumento */
int		check_arg_size(int argc);
int		is_only_digits(char *str);
int		fits_in_int(char *str);
int		print_error(char *message, char *arg);

/* parsing.c — validar e guardar os argumentos */
int		parsing_validation(int argc, char **argv);
void	fill_config(char **argv, t_config *config);
int		ends_before_start(t_config *config);

/* time.c — relógio e espera precisa */
long	get_time_ms(void);
long	elapsed_ms(long start);
void	precise_sleep(t_sim *sim, long ms);

/* sim.c — criar e destruir a simulação, escrever logs */
int		init_sim(t_sim *sim, t_config *config);
void	print_status(t_coder *coder, char *message);
void	free_sim(t_sim *sim);

/* sync.c — bandeira de fim e porta de partida */
int		is_simulation_over(t_sim *sim);
void	wait_gate(t_sim *sim);
void	open_gate(t_sim *sim);

/* coder.c — rotina dos coders, criar e esperar as threads */
void	join_coders(t_sim *sim, int count);
int		start_coders(t_sim *sim);

/* monitor.c — vigiar burnouts e o fim por compilações */
int		start_monitor(t_sim *sim);

#endif
