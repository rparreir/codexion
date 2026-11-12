#include "codexion.h"

int	has_priority(t_request *a, t_request *b, int scheduler)
{
    if (scheduler == 0)/*fifo*/
        return (a->ticket < b->ticket);
    else/*edf*/
    {
        if (a->deadline == b->deadline)
            return (a->ticket < b->ticket);
        else
            return (a->deadline < b->deadline);
    }
}
/* devolve 1 se o a vai à frente do b, 0 se não */

void	join_queue(t_coder *coder, t_dongle *dongle)
{
    t_request r;
    t_sim	*sim;

	sim = coder->shared;
    pthread_mutex_lock (&dongle->mutex);
    r.coder = coder;
    r.deadline = coder->burnout_deadline;
    r.ticket = dongle->next_ticket;
    dongle->next_ticket++;
    queue_push(dongle, r, sim->config.scheduler);
    pthread_mutex_unlock (&dongle->mutex);
}