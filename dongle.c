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

int	take_dongle(t_coder *coder, t_dongle *dongle)
{
	t_sim	*sim;

	sim = coder->shared;
	while (1)
	{
		if (is_simulation_over(sim))
			return (0);
		pthread_mutex_lock (&dongle->mutex);
		if (dongle->taken == 0)
		{
			dongle->taken = 1;
			pthread_mutex_unlock (&dongle->mutex);
			print_status(coder, "has taken a dongle");
			return (1);
		}
		else
		{
			pthread_mutex_unlock (&dongle->mutex);
		}
		usleep(500);
	}
}

void	release_dongle(t_dongle *dongle)
{
	pthread_mutex_lock (&dongle->mutex);
	dongle->taken = 0;
	pthread_mutex_unlock (&dongle->mutex);
}

int	take_dongles(t_coder *coder)
{
	t_dongle	*first;
	t_dongle	*second;

	if (coder->id % 2 == 0)
	{
		first = coder->left;
		second = coder->right;
	}
	else
	{
		first = coder->right;
		second = coder->left;
	}
	if (!take_dongle(coder, first))
		return (0);
	if (!take_dongle(coder, second))
	{
		release_dongle(first);
		return (0);
	}
	return (1);
}