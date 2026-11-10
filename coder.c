#include "codexion.h"

void	init_coders(t_sim *sim)
{
	int	i;
	int n;

	i = 0;
	while (i < sim->config.number_of_coders)
	{
		n = (i + 1) % sim->config.number_of_coders;
		sim->coders[i].id = i + 1;
		sim->coders[i].compiles_done = 0;
		sim->coders[i].burnout_deadline = sim->start_time
			+ sim->config.time_to_burnout;
		sim->coders[i].shared = sim;
		sim->coders[i].left = &sim->dongles[i];
		sim->coders[i].right = &sim->dongles[n];
		i++;
	}
}

/* compila com os dois dongles na mão */
void	compile(t_coder *coder)
{
	t_sim	*sim;

	sim = coder->shared;
	pthread_mutex_lock(&sim->stop_mutex);
	coder->burnout_deadline = get_time_ms() + sim->config.time_to_burnout;
	pthread_mutex_unlock(&sim->stop_mutex);
	print_status(coder, "is compiling");
	precise_sleep(sim, sim->config.time_to_compile);
	pthread_mutex_lock(&sim->stop_mutex);
	coder->compiles_done++;
	pthread_mutex_unlock(&sim->stop_mutex);
	
}

void	*coder_routine(void *arg)
{
	t_coder	*coder;
	t_sim	*sim;

	coder = (t_coder *)arg;
	sim = coder->shared;
	wait_gate(sim);
	while (!is_simulation_over(sim))
	{
		if (!take_dongles(coder))
			return (NULL);
		compile(coder);
		print_status(coder, "is debugging");
		release_dongle(coder, coder->left);
		release_dongle(coder, coder->right);
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
