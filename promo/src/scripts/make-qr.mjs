import QRCode from 'qrcode';
import {fileURLToPath} from 'node:url';

const out = fileURLToPath(new URL('../../public/qr.png', import.meta.url));
const url = 'https://github.com/Muanyan-mjq/Time';

await QRCode.toFile(out, url, {
  errorCorrectionLevel: 'M',
  type: 'png',
  width: 600,
  margin: 1,
  color: {dark: '#121212', light: '#FFFFFF'},
});

console.log('QR code ->', out, '|', url);
