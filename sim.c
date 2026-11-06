#include "codexion.h"

int	init_sim(t_sim *sim, t_config *config)
{
	sim->config = *config;
	sim->start_time = get_time_ms();
	sim->simulation_over = 0;
	sim->started = 0;
	sim->ready = 0;
	sim->coders = malloc(sizeof(t_coder) * config->number_of_coders);
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
	if (!init_dongles(sim))
	{
		destroy_sync(sim);
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
	destroy_dongles(sim, sim->config.number_of_coders);
	destroy_sync(sim);
	free(sim->coders);
}
