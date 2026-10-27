# include "codexion.h"

long	get_time_ms(void)
{
	struct timespec	ts;

	clock_gettime(CLOCK_REALTIME, &ts);
	return (ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}

long	elapsed_ms(long start)
{
	return (get_time_ms() - start);
}

/* espera aos bocadinhos de 0,5 ms: o atraso final fica do tamanho de uma volta */
void	precise_sleep(long ms)
{
	long	start;

	start = get_time_ms();
	while (elapsed_ms(start) < ms)
		usleep(500);
}
