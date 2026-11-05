#include "codexion.h"

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

int	is_simulation_over(t_sim *sim)
{
	int	over;

	pthread_mutex_lock(&sim->stop_mutex);
	over = sim->simulation_over;
	pthread_mutex_unlock(&sim->stop_mutex);
	return (over);
}

/* o coder espera na porta até o main dar o tiro (started = 1) */
void	wait_gate(t_sim *sim)
{
	pthread_mutex_lock(&sim->stop_mutex);
	sim->ready++;
	while (!sim->started)
		pthread_cond_wait(&sim->start_cond, &sim->stop_mutex);
	pthread_mutex_unlock(&sim->stop_mutex);
}

void	open_gate(t_sim *sim)
{
	int	i;

	pthread_mutex_lock(&sim->stop_mutex);
	while (sim->ready < sim->config.number_of_coders)
	{
		pthread_mutex_unlock(&sim->stop_mutex);
		usleep(1000);
		pthread_mutex_lock(&sim->stop_mutex);
	}
	sim->start_time = get_time_ms();
	i = 0;
	while (i < sim->config.number_of_coders)
	{
		sim->coders[i].burnout_deadline = sim->start_time
			+ sim->config.time_to_burnout;
		i++;
	}
	sim->started = 1;
	pthread_cond_broadcast(&sim->start_cond);
	pthread_mutex_unlock(&sim->stop_mutex);
}
