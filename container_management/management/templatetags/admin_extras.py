from __future__ import annotations

import ast
from typing import Any

from django import template

register = template.Library()


@register.filter
def to_list_if_string(value: Any) -> Any:
    """Convert stringified list/tuple from admin actions into real objects."""
    if isinstance(value, str):
        try:
            parsed = ast.literal_eval(value)
        except (ValueError, SyntaxError):
            return value
        return parsed
    return value
