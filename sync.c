#include "codexion.h"


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
	int i;

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
		sim->coders[i].burnout_deadline = sim->start_time + sim->config.time_to_burnout;
		i++;
	}
	sim->started = 1;
	pthread_cond_broadcast(&sim->start_cond);
	pthread_mutex_unlock(&sim->stop_mutex);
}