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
    print_coders(&sim);
    free_sim(&sim);
    return 0;
}
