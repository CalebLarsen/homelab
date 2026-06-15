import base64
import hashlib

class FilterModule(object):
    def filters(self):
        return {
            'qbittorrent_hash': self.qbittorrent_hash
        }

    def qbittorrent_hash(self, password):
        """
        Calculates the PBKDF2 hash for qBittorrent configuration.
        Matches the logic in the original shell script.
        """
        salt = hashlib.sha256(b'qbittorrent-homelab-v1:' + password.encode()).digest()[:16]
        key = hashlib.pbkdf2_hmac('sha512', password.encode(), salt, 100000)

        salt_b64 = base64.b64encode(salt).decode()
        key_b64 = base64.b64encode(key).decode()

        return "@ByteArray({}:{})".format(salt_b64, key_b64)
