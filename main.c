# include "codexion.h"


int main(int argc, char **argv)
{
    t_config config;
    t_sim	sim;

    if (!parsing_validation(argc, argv))
        return (1);
    fill_config(argv, &config);
    if (!init_sim(&sim, &config))
	    return (1);
    print_status(&sim.coders[0], "is compiling");
    precise_sleep(200);
    print_status(&sim.coders[0], "is debugging");
    free_sim(&sim);
    return 0;
}
