"""Exercise shipped TLS translations and certificate errors in narrow browser dialogs."""
import json
import mimetypes
from pathlib import Path
from urllib.parse import urlsplit

from playwright.sync_api import expect, sync_playwright

app = Path(__file__).resolve().parents[1]
root = app / 'remote-ui'
html = (root / 'index.html').read_text().replace(
    '<script type="module" src="static/main.js?v=__KSV__"></script>', '')
info = {'certificate': 'public certificate', 'fingerprint': 'abcdef01' * 8,
        'expires': '2027-09-23T12:00:00Z', 'imported': False, 'expired': False}


def serve(route):
    path = urlsplit(route.request.url).path
    if path == '/':
        route.fulfill(body=html, content_type='text/html')
    elif path == '/api/commands/importTlsCertificate':
        route.fulfill(json={'ok': False, 'error':
            'PlatformException(tls, Certificate and private key do not match., null, null)'})
    elif path.startswith('/api/commands/'):
        route.fulfill(json={'ok': True, 'data': info})
    else:
        file = root / path.lstrip('/')
        if file.is_file():
            route.fulfill(body=file.read_bytes(),
                          content_type=mimetypes.guess_type(file)[0] or 'application/octet-stream')
        else:
            route.fulfill(status=404)


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True, args=['--no-sandbox'])
    for locale in ['en', 'de', 'es', 'fr']:
        catalog = json.loads((app / f'l10n/effective/ui_{locale}.arb').read_text())
        for theme in ['light', 'dark']:
            # Browser language deliberately differs from the selected kiosk language.
            page = browser.new_page(viewport={'width': 360, 'height': 800}, locale='en-US')
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.route('https://kiosk.test/**', serve)
            page.goto('https://kiosk.test/')
            page.evaluate('''async ({locale, theme}) => {
                const tls = await import('/static/tls.js');
                (await import('/static/localization.js')).setLanguagePreference(locale);
                document.querySelectorAll('body > section').forEach(node => node.style.display = 'none');
                document.documentElement.dataset.theme = theme;
                const root = document.createElement('main');
                root.id = 'tls-test';
                document.body.append(root);
                tls.renderTlsSettings(root);
            }''', {'locale': locale, 'theme': theme})
            panel = page.locator('#tls-test')
            expect(panel).to_contain_text(catalog['tlsCertificateType'])
            expect(panel).to_contain_text(catalog['tlsCertificateManagement'])
            expected_date = page.evaluate('''locale => new Date('2027-09-23T12:00:00Z')
                .toLocaleDateString(locale, {year: 'numeric', month: 'short', day: 'numeric'})''', locale)
            expect(panel).to_contain_text(expected_date)
            panel.get_by_role('button', name=catalog['commonImport'], exact=True).click()
            expect(page.locator('.modal-title')).to_have_text(catalog['tlsImportCertificate'])
            fields = page.locator('.tls-import textarea')
            fields.nth(0).fill('invalid certificate fixture')
            fields.nth(1).fill('invalid private key fixture')
            page.locator('.modal-foot').get_by_role('button', name=catalog['commonImport'], exact=True).click()
            expect(page.locator('.tls-import [role="alert"]')).to_contain_text(catalog['tlsKeyMismatch'])
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth'), (locale, theme)
            page.locator('.modal-foot').get_by_role('button', name=catalog['commonCancel'], exact=True).click()
            panel.get_by_role('button', name=catalog['tlsReplace'], exact=True).click()
            expect(page.locator('.modal-body')).to_contain_text(catalog[
                'tlsGenerateANewPrivateKeyAndCertificateActiveEncryptedConnectionsWillCloseBrowsersMayAskYouToAcceptTheNewCertificate'])
            page.locator('.modal-foot').get_by_role('button', name=catalog['commonCancel'], exact=True).click()
            page.evaluate('''async () => {
                (await import('/static/tls.js')).confirmRemoteProtocol(false)
                    .then(value => window.protocolConfirmed = value);
            }''')
            expect(page.locator('.modal-title')).to_have_text(catalog['tlsChangeConnectionProtocol'])
            expect(page.locator('.tls-address .copy-value')).to_have_text('http://kiosk.test/')
            page.locator('.modal-foot').get_by_role('button', name=catalog['tlsConfirm'], exact=True).click()
            assert page.evaluate('window.protocolConfirmed') is True
            assert not errors, errors
            page.close()
    browser.close()
print('TLS browser dialogs passed in four languages and both themes at 360px.')
