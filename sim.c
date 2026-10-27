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

int	init_sim(t_sim *sim, t_config *config)
{
	sim->config = *config;
	sim->start_time = get_time_ms();
	sim->coders = malloc(sizeof(t_coder) * config->number_of_coders);
	if (!sim->coders)
	{
		fprintf(stderr, "Error: not enough memory for %d coders\n",
			config->number_of_coders);
		return (0);
	}
	if (pthread_mutex_init(&sim->log_mutex, NULL) != 0)
	{
		fprintf(stderr, "Error: could not create the log mutex\n");
		free(sim->coders);
		return (0);
	}
	init_coders(sim);
	return (1);
}

void	free_sim(t_sim *sim)
{
	pthread_mutex_destroy(&sim->log_mutex);
	free(sim->coders);
}