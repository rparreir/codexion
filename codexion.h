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

/* declaração antecipada: o t_request aponta para o t_coder,
   que só é definido mais abaixo */
typedef struct s_coder	t_coder;

/* o pedido que um coder deixa na fila de um dongle enquanto espera:
   deadline = cópia do burnout_deadline no momento em que pede;
   ticket = senha, por ordem de chegada a este dongle (0, 1, 2...) */
typedef struct s_request
{
	t_coder	*coder;
	long	deadline;
	long	ticket;
}	t_request;

/* queue = a fila (heap) de quem espera por este dongle: só 2 coders
   usam cada dongle, por isso 2 lugares chegam;
   next_ticket = a próxima senha a dar */
typedef struct s_dongle
{
	pthread_mutex_t	mutex;
	int				id;
	int				taken;
	long			available_at;
	t_request		queue[2];
	int				queue_size;
	long			next_ticket;
}	t_dongle;

struct s_coder
{
	int			id;
	long		burnout_deadline;
	int			compiles_done;
	pthread_t	thread;
	t_sim		*shared;
	t_dongle	*left;
	t_dongle	*right;
};

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
	t_dongle		*dongles;
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

/* sync.c — criar os mutexes e a cond, bandeira de fim, porta de partida */
int		init_sync(t_sim *sim);
int		is_simulation_over(t_sim *sim);
void	wait_gate(t_sim *sim);
void	open_gate(t_sim *sim);
void	destroy_sync(t_sim *sim);

/* dongle.c — criar e destruir os dongles */
int		init_dongles(t_sim *sim);
void	destroy_dongles(t_sim *sim, int count);
void	release_dongle(t_coder *coder, t_dongle *dongle);
int		take_dongles(t_coder *coder);

/* coder.c — criar os coders, a rotina, criar e esperar as threads */
void	init_coders(t_sim *sim);
void	join_coders(t_sim *sim, int count);
int		start_coders(t_sim *sim);

/* monitor.c — vigiar burnouts e o fim por compilações */
int		start_monitor(t_sim *sim);

/*scheduler.c - define a ordem de prioridades dos coderes para que possam pegar os dongles*/
int		has_priority(t_request *a, t_request *b, int scheduler);
void	join_queue(t_coder *coder, t_dongle *dongle);

/*queue.c*/
void	queue_push(t_dongle *dongle, t_request request, int scheduler);
void	queue_pop(t_dongle *dongle, int scheduler);
#endif
