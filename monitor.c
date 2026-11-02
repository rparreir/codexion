# include "codexion.h"

int	find_burnout(t_sim *sim)
{
	long	now;
	int		i;

	now = get_time_ms();
	i = 0;
	while (i < sim->config.number_of_coders)
	{
		if (now > sim->coders[i].burnout_deadline)
			return (i);
		i++;
	}
	return (-1);
}

int	all_compiled(t_sim *sim)
{
	int	i;

	i = 0;
	while (i < sim->config.number_of_coders)
	{
		if (sim->coders[i].compiles_done
			< sim->config.number_of_compiles_required)
			return (0);
		i++;
	}
	return (1);
}

void	raise_burnout(t_sim *sim, int i)
{
	pthread_mutex_lock(&sim->log_mutex);
	pthread_mutex_lock(&sim->stop_mutex);
	sim->simulation_over = 1;
	pthread_mutex_unlock(&sim->stop_mutex);
	printf("%ld %d burned out\n", elapsed_ms(sim->start_time),
		sim->coders[i].id);
	pthread_mutex_unlock(&sim->log_mutex);
}

void	*monitor_routine(void *arg)
{
	t_sim	*sim;
	int		burned;
	int		done;

	sim = (t_sim *)arg;
	while (1)
	{
		pthread_mutex_lock(&sim->stop_mutex);
		burned = find_burnout(sim);
		done = all_compiled(sim);
		if (burned == -1 && done)
			sim->simulation_over = 1;
		pthread_mutex_unlock(&sim->stop_mutex);
		if (burned != -1)
		{
			raise_burnout(sim, burned);
			return (NULL);
		}
		if (done)
			return (NULL);
		usleep(1000);
	}
	return (NULL);
}

int	start_monitor(t_sim *sim)
{
	if (pthread_create(&sim->monitor, NULL, monitor_routine, sim) != 0)
	{
		fprintf(stderr, "Error: could not create the monitor thread\n");
		pthread_mutex_lock(&sim->stop_mutex);
		sim->simulation_over = 1;
		pthread_mutex_unlock(&sim->stop_mutex);
		join_coders(sim, sim->config.number_of_coders);
		return (0);
	}
	return (1);
}
