#include "codexion.h"

int	main(int argc, char **argv)
{
	t_config	config;
	t_sim		sim;

	if (!parsing_validation(argc, argv))
		return (1);
	fill_config(argv, &config);
	if (ends_before_start(&config))
		return (0);
	if (!init_sim(&sim, &config))
		return (1);
	if (!start_coders(&sim))
	{
		free_sim(&sim);
		return (1);
	}
	open_gate(&sim);
	if (!start_monitor(&sim))
	{
		free_sim(&sim);
		return (1);
	}
	pthread_join(sim.monitor, NULL);
	join_coders(&sim, sim.config.number_of_coders);
	free_sim(&sim);
	return (0);
}
