from app.models import User, UserRole

PROFILE_FIELDS = [
    "phone",
    "address_line",
    "city",
    "district",
    "state",
    "pincode",
]


def missing_profile_fields(user: User) -> list[str]:
    missing = []
    for field in PROFILE_FIELDS:
        value = getattr(user, field, None)
        if value is None or str(value).strip() == "":
            missing.append(field)
    return missing


def is_profile_complete(user: User) -> bool:
    return not missing_profile_fields(user)


def profile_completion_message(role: UserRole) -> str:
    if role == UserRole.farmer:
        return "Please complete your profile before listing or selling material."
    if role == UserRole.artisan:
        return "Please complete your profile before listing products or buying material."
    return "Please complete your profile before placing an order or custom request."
