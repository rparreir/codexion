#include "codexion.h"

/* temporário: apagar este ficheiro quando a simulação existir */
void	print_config(t_config *config)
{
	printf("coders=%d\n", config->number_of_coders);
	printf("burnout=%ld\n", config->time_to_burnout);
	printf("compile=%ld\n", config->time_to_compile);
	printf("debug=%ld\n", config->time_to_debug);
	printf("refactor=%ld\n", config->time_to_refactor);
	printf("compiles=%d\n", config->number_of_compiles_required);
	printf("cooldown=%ld\n", config->dongle_cooldown);
	if (config->scheduler == 0)
		printf("scheduler=fifo\n");
	else
		printf("scheduler=edf\n");
}

/* temporário: prova que o ponteiro shared de cada coder aponta para a t_sim */
void	print_coders(t_sim *sim)
{
	int	i;

	i = 0;
	while (i < sim->config.number_of_coders)
	{
		printf("coder %d: burnout=%ld\n", sim->coders[i].id,
			sim->coders[i].shared->config.time_to_burnout);
		i++;
	}
}
