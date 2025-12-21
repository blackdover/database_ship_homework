from django.contrib.auth.decorators import login_required, user_passes_test
from django.db.models import Q
from django.shortcuts import render

from .models import (
    Booking,
    ContainerMaster,
    Party,
    Task,
    VesselVisit,
)


@login_required
@user_passes_test(lambda u: u.is_staff)
def aggregate_search(request):
    """
    聚合搜索页：一个输入框同时查询多个核心模型，并给出快捷操作链接。
    """
    query = (request.GET.get('q') or '').strip()

    containers = bookings = tasks = visits = parties = []
    if query:
        containers = (
            ContainerMaster.objects.select_related('type_code', 'owner_party_id')
            .filter(
                Q(container_number__icontains=query)
                | Q(type_code__type_code__icontains=query)
                | Q(owner_party_id__party_name__icontains=query)
            )
            .order_by('-container_master_id')[:10]
        )

        bookings = (
            Booking.objects.select_related('voyage_id', 'shipper_party_id', 'consignee_party_id')
            .filter(
                Q(booking_number__icontains=query)
                | Q(status__icontains=query)
                | Q(shipper_party_id__party_name__icontains=query)
                | Q(consignee_party_id__party_name__icontains=query)
            )
            .order_by('-booking_id')[:10]
        )

        tasks = (
            Task.objects.select_related('container_master_id', 'vessel_visit_id')
            .filter(
                Q(container_master_id__container_number__icontains=query)
                | Q(task_type__icontains=query)
                | Q(status__icontains=query)
            )
            .order_by('-task_id')[:10]
        )

        visits = (
            VesselVisit.objects.select_related('vessel_id', 'port_id')
            .filter(
                Q(vessel_id__vessel_name__icontains=query)
                | Q(voyage_number_in__icontains=query)
                | Q(voyage_number_out__icontains=query)
                | Q(port_id__port_name__icontains=query)
            )
            .order_by('-ata', '-vessel_visit_id')[:10]
        )

        parties = (
            Party.objects.filter(
                Q(party_name__icontains=query)
                | Q(contact_person__icontains=query)
                | Q(scac_code__icontains=query)
            )
            .order_by('-party_id')[:10]
        )

    context = {
        'query': query,
        'containers': containers,
        'bookings': bookings,
        'tasks': tasks,
        'visits': visits,
        'parties': parties,
    }
    return render(request, 'management/aggregate_search.html', context)
