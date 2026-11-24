// The selected document is data. Read only the main XML part and ignore external relationships.
import { unzipSync, strFromU8 } from "fflate";
export function documentXML(encoded) {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const bytes = new Uint8Array(Math.floor(encoded.length * 3 / 4));
    let bits = 0, value = 0, length = 0;
    for (const ch of encoded) {
        if (ch === "=") break;
        value = (value << 6) | alphabet.indexOf(ch);
        bits += 6;
        if (bits >= 8) { bits -= 8; bytes[length++] = (value >> bits) & 255; }
    }
    const filename = "word/document.xml";
    let entries = 0;
    const parts = unzipSync(bytes.subarray(0, length), { filter(entry) {
        if (++entries > 2000) throw Error("Choose a smaller document.");
        if (entry.name !== filename) return false;
        if (entry.originalSize > 8 * 1024 * 1024) throw Error("Document text exceeds the import limit.");
        return true;
    }});
    if (!parts[filename]) throw Error("Invalid Word document.");
    return strFromU8(parts[filename]);
}
