#include "codexion.h"

/* troca dois pedidos de lugar na fila */
void	swap_requests(t_request *a, t_request *b)
{
	t_request	tmp;

	tmp = *a;
	*a = *b;
	*b = tmp;
}

/* põe o pedido no fim da fila e sobe-o enquanto tiver prioridade sobre
   o pai (sift-up); chamar com o mutex do dongle trancado */
void	queue_push(t_dongle *dongle, t_request request, int scheduler)
{
	t_request	*q;
	int			i;

	q = dongle->queue;
	i = dongle->queue_size;
	q[i] = request;
	dongle->queue_size++;
	while (i > 0 && has_priority(&q[i], &q[(i - 1) / 2], scheduler))
	{
		swap_requests(&q[i], &q[(i - 1) / 2]);
		i = (i - 1) / 2;
	}
}

/* desce o pedido do lugar i enquanto um dos filhos tiver prioridade
   sobre ele (sift-down) */
void	sift_down(t_dongle *dongle, int i, int scheduler)
{
	t_request	*q;
	int			best;
	int			child;

	q = dongle->queue;
	while (1)
	{
		best = i;
		child = 2 * i + 1;
		if (child < dongle->queue_size
			&& has_priority(&q[child], &q[best], scheduler))
			best = child;
		child = 2 * i + 2;
		if (child < dongle->queue_size
			&& has_priority(&q[child], &q[best], scheduler))
			best = child;
		if (best == i)
			return ;
		swap_requests(&q[i], &q[best]);
		i = best;
	}
}

/* tira o 1.º da fila: o último passa para a raiz e desce até ao sítio
   certo; chamar com o mutex do dongle trancado e a fila não vazia */
void	queue_pop(t_dongle *dongle, int scheduler)
{
	dongle->queue_size--;
	dongle->queue[0] = dongle->queue[dongle->queue_size];
	sift_down(dongle, 0, scheduler);
}