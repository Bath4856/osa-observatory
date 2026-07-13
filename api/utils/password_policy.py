"""
Politique de complexité des mots de passe -- module partage, reutilise par
confirm-email (definition initiale), le changement de mot de passe et la
reinitialisation. Validation cote serveur uniquement fiable -- toute
validation cote client n'est qu'une aide a la saisie, jamais une garantie.
"""
import re


def validate_password_strength(password: str) -> str | None:
    """Retourne un message d'erreur (fr) si le mot de passe ne respecte pas
    la politique, ou None si valide."""
    if not password or len(password) < 8:
        return "Le mot de passe doit contenir au moins 8 caractères."
    if not re.search(r'[a-z]', password):
        return "Le mot de passe doit contenir au moins une lettre minuscule."
    if not re.search(r'[A-Z]', password):
        return "Le mot de passe doit contenir au moins une lettre majuscule."
    if not re.search(r'[0-9]', password):
        return "Le mot de passe doit contenir au moins un chiffre."
    if not re.search(r'[^A-Za-z0-9]', password):
        return "Le mot de passe doit contenir au moins un caractère spécial."
    return None
