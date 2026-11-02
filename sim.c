#include "codexion.h"

void	init_coders(t_sim *sim)
{
	int	i;

	i = 0;
	while (i < sim->config.number_of_coders)
	{
		sim->coders[i].id = i + 1;
		sim->coders[i].compiles_done = 0;
		sim->coders[i].burnout_deadline = sim->start_time
			+ sim->config.time_to_burnout;
		sim->coders[i].shared = sim;
		i++;
	}
}

int	init_sync(t_sim *sim)
{
	if (pthread_mutex_init(&sim->log_mutex, NULL) != 0)
	{
		fprintf(stderr, "Error: could not create the log mutex\n");
		return (0);
	}
	if (pthread_mutex_init(&sim->stop_mutex, NULL) != 0)
	{
		fprintf(stderr, "Error: could not create the stop mutex\n");
		pthread_mutex_destroy(&sim->log_mutex);
		return (0);
	}
	if (pthread_cond_init(&sim->start_cond, NULL) != 0)
	{
		fprintf(stderr, "Error: could not create the start condition\n");
		pthread_mutex_destroy(&sim->stop_mutex);
		pthread_mutex_destroy(&sim->log_mutex);
		return (0);
	}
	return (1);
}

int	init_sim(t_sim *sim, t_config *config)
{
	sim->config = *config;
	sim->start_time = get_time_ms();
	sim->simulation_over = 0;
	sim->started = 0;
	sim->coders = malloc(sizeof(t_coder) * config->number_of_coders);
	sim->ready = 0;
	if (!sim->coders)
	{
		fprintf(stderr, "Error: not enough memory for %d coders\n",
			config->number_of_coders);
		return (0);
	}
	if (!init_sync(sim))
	{
		free(sim->coders);
		return (0);
	}
	init_coders(sim);
	return (1);
}

void	print_status(t_coder *coder, char *message)
{
	t_sim	*sim;

	sim = coder->shared;
	pthread_mutex_lock(&sim->log_mutex);
	if (!is_simulation_over(sim))
		printf("%ld %d %s\n", elapsed_ms(sim->start_time), coder->id, message);
	pthread_mutex_unlock(&sim->log_mutex);
}

void	free_sim(t_sim *sim)
{
	pthread_cond_destroy(&sim->start_cond);
	pthread_mutex_destroy(&sim->stop_mutex);
	pthread_mutex_destroy(&sim->log_mutex);
	free(sim->coders);
}
