#include "codexion.h"

int	init_dongles(t_sim *sim)
{
	int	i;

	sim->dongles = malloc(sizeof(t_dongle) * sim->config.number_of_coders);
	if (!sim->dongles)
	{
		fprintf(stderr, "Error: not enough memory for %d dongles\n",
			sim->config.number_of_coders);
		return (0);
	}
	i = 0;
	while (i < sim->config.number_of_coders)
	{
		if (pthread_mutex_init(&sim->dongles[i].mutex, NULL) != 0)
		{
			fprintf(stderr, "Error: could not create the mutex of dongle %d\n",
				i + 1);
			destroy_dongles(sim, i);
			return (0);
		}
		sim->dongles[i].id = i + 1;
		sim->dongles[i].taken = 0;
		sim->dongles[i].available_at = 0;
		i++;
	}
	return (1);
}

/* destrói os mutexes dos primeiros "count" dongles e liberta o array */
void	destroy_dongles(t_sim *sim, int count)
{
	int	i;

	i = 0;
	while (i < count)
	{
		pthread_mutex_destroy(&sim->dongles[i].mutex);
		i++;
	}
	free(sim->dongles);
}