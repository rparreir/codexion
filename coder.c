#include "codexion.h"


void	*coder_routine(void *arg)
{
	t_coder	*coder;
	t_sim	*sim;

	coder = (t_coder *)arg;
	sim = coder->shared;
	wait_gate(sim);
	while (!is_simulation_over(sim))
	{
		pthread_mutex_lock(&sim->stop_mutex);
		coder->burnout_deadline = get_time_ms() + sim->config.time_to_burnout;
		pthread_mutex_unlock(&sim->stop_mutex);
		print_status(coder, "is compiling");
		precise_sleep(sim, sim->config.time_to_compile);
		pthread_mutex_lock(&sim->stop_mutex);
		coder->compiles_done++;
		pthread_mutex_unlock(&sim->stop_mutex);
		print_status(coder, "is debugging");
		precise_sleep(sim, sim->config.time_to_debug);
		print_status(coder, "is refactoring");
		precise_sleep(sim, sim->config.time_to_refactor);
	}
	return (NULL);
}

/* espera pelos primeiros "count" coders (todos, ou só os que arrancaram) */
void	join_coders(t_sim *sim, int count)
{
	int	i;

	i = 0;
	while (i < count)
	{
		pthread_join(sim->coders[i].thread, NULL);
		i++;
	}
}

int	start_coders(t_sim *sim)
{
	int	i;

	i = 0;
	while (i < sim->config.number_of_coders)
	{
		if (pthread_create(&sim->coders[i].thread, NULL,
				coder_routine, &sim->coders[i]) != 0)
		{
			fprintf(stderr, "Error: could not create the thread of coder %d\n",
				i + 1);
			pthread_mutex_lock(&sim->stop_mutex);
			sim->simulation_over = 1;
			sim->started = 1;                               
			pthread_cond_broadcast(&sim->start_cond); 
			pthread_mutex_unlock(&sim->stop_mutex);
			join_coders(sim, i);
			return (0);
		}
		i++;
	}
	return (1);
}
