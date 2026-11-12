import {q} from '../db/index.mjs';
import fs from 'node:fs';
import path from 'node:path';
import {ROOT} from '../db/index.mjs';

// A child can use templates from itself, its parent brand and the client account.
// The nearest level wins when choosing a default.
export async function templatesFor(client,db={query:q}){
 const chain=client.chain||[];
 if(!chain.length)return [];
 const ids=chain.map(n=>n.id);
 const rows=(await db.query("SELECT * FROM records WHERE client_id=ANY($1) AND kind='DesignTemplate' AND status<>'archived' ORDER BY created_at DESC",[ids])).rows;
 const distance=new Map(chain.map((n,i)=>[n.id,i]));
 const names=new Map(chain.map(n=>[n.id,n.name]));
 return rows.sort((a,b)=>(distance.get(a.client_id)??99)-(distance.get(b.client_id)??99)||new Date(b.created_at)-new Date(a.created_at))
  .map(r=>({...r,source_id:r.client_id,source_name:names.get(r.client_id)||'Parent workspace',inherited:r.client_id!==client.id}));
}

export async function chooseDesignTemplate(client,templateId,mode,db={query:q}){
 const templates=await templatesFor(client,db);
 if(templateId){
  const found=templates.find(t=>t.id===templateId);
  if(!found)throw new Error('Choose a template available to this workspace');
  return found;
 }
 return templates.find(t=>t.data?.is_default)||null;
}

// Resolve the optional image reference only from the workspace level that owns the template.
export async function templateForDesign(template,db={query:q}){
 if(!template)return null;
 let reference_image_path=null;
 const fid=template.data?.reference_image_file_id;
 if(fid){
  const file=(await db.query("SELECT storage_path,mime FROM files WHERE id=$1 AND client_id=$2",[fid,template.source_id||template.client_id])).rows[0];
  if(!file||!/^image\/(png|jpeg|webp)$/.test(file.mime))throw new Error('The template reference image is unavailable. Upload it again in Client & brand.');
  const root=path.resolve(ROOT,'.local');
  const absolute=path.resolve(root,file.storage_path);
  if(!absolute.startsWith(root+path.sep)||!fs.existsSync(absolute))throw new Error('The template reference image is unavailable. Upload it again in Client & brand.');
  reference_image_path=absolute;
 }
 return {...template,reference_image_path};
}
