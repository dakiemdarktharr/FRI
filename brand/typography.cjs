const fs=require('node:fs'),path=require('node:path');
const weights=[['Regular',400],['SemiBold',600],['Bold',700]];
function faces(base='data') {return weights.map(([name,weight])=>`@font-face{font-family:BeVietnamPro;src:url(${base==='data'?'data:font/woff2;base64,'+fs.readFileSync(path.join(__dirname,'fonts/be-vietnam-pro/BeVietnamPro-'+name+'.woff2')).toString('base64'):base+'BeVietnamPro-'+name+'.woff2'}) format('woff2');font-weight:${weight};font-style:normal;font-display:swap}`).join('\n')}
function typography(){return '/* Bundled Be Vietnam Pro font license\n'+fs.readFileSync(path.join(__dirname,'fonts/be-vietnam-pro/OFL.txt'),'utf8').replaceAll('*/','* /')+'\n*/\n'+faces()+`body,button,input,select,textarea{font-family:BeVietnamPro,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}h1,h2,h3{font-family:BeVietnamPro,sans-serif}h1,h2{font-weight:700;line-height:1.2}h3,strong,b{font-weight:600}button{font-weight:600}`}
module.exports={faces,typography,weights};
