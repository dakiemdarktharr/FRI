import {readFile} from 'node:fs/promises';
export async function typography(){
 const font=await readFile(new URL('fonts/InterVariable.woff2',import.meta.url));
 return `@font-face{font-family:Inter;src:url(data:font/woff2;base64,${font.toString('base64')}) format('woff2');font-weight:100 900;font-style:normal;font-display:swap}body,button,input,select,textarea{font-family:Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}h1,h2,h3{font-family:Inter,sans-serif;font-optical-sizing:auto}h1,h2{font-weight:600}h3,strong,b{font-weight:600}button{font-weight:600}`;
}
