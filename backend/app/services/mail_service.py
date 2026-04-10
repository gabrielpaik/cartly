import smtplib
from email.message import EmailMessage
from typing import Optional

from ..core.settings import settings


class MailServiceError(Exception):
    pass



def _smtp_enabled() -> bool:
    return bool(settings.smtp_host.strip() and settings.smtp_username.strip() and settings.smtp_password.strip())



def send_email(*, to_email: str, subject: str, text_body: str, html_body: Optional[str] = None) -> None:
    if not _smtp_enabled():
        raise MailServiceError('SMTP 설정이 비어 있어 메일을 보낼 수 없어')

    message = EmailMessage()
    message['Subject'] = subject
    message['From'] = settings.smtp_from_email.strip() or settings.smtp_username.strip()
    message['To'] = to_email
    message.set_content(text_body)
    if html_body:
        message.add_alternative(html_body, subtype='html')

    if settings.smtp_use_ssl:
        with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
            smtp.login(settings.smtp_username, settings.smtp_password)
            smtp.send_message(message)
        return

    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
        smtp.ehlo()
        if settings.smtp_use_starttls:
            smtp.starttls()
            smtp.ehlo()
        smtp.login(settings.smtp_username, settings.smtp_password)
        smtp.send_message(message)
