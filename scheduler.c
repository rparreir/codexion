#include "codexion.h"

/* devolve 1 se o pedido a vai à frente do b, 0 se não;
   fifo (scheduler 0): ganha a senha mais baixa;
   edf (scheduler 1): ganha o prazo mais perto e, se empatarem, a senha */
int	has_priority(t_request *a, t_request *b, int scheduler)
{
	if (scheduler == 0)
		return (a->ticket < b->ticket);
	else
	{
		if (a->deadline == b->deadline)
			return (a->ticket < b->ticket);
		else
			return (a->deadline < b->deadline);
	}
}

/* o coder entra na fila do dongle: tira a senha seguinte e guarda uma cópia
   do seu prazo, tudo com o mutex do dongle trancado */
void	join_queue(t_coder *coder, t_dongle *dongle)
{
	t_request	r;
	t_sim		*sim;

	sim = coder->shared;
	pthread_mutex_lock (&dongle->mutex);
	r.coder = coder;
	r.deadline = coder->burnout_deadline;
	r.ticket = dongle->next_ticket;
	dongle->next_ticket++;
	queue_push(dongle, r, sim->config.scheduler);
	pthread_mutex_unlock (&dongle->mutex);
}
