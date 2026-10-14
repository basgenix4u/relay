import assert from 'node:assert/strict';
import { chromium, expect } from '@playwright/test';
import fs from 'node:fs/promises';
import path from 'node:path';

const base = process.env.RELAY_TEST_URL || 'http://127.0.0.1:8000';
const artifacts = process.env.RELAY_TEST_ARTIFACTS || path.resolve('.cache/relay-checks');
await fs.mkdir(artifacts, {recursive: true});
const browser = await chromium.launch({headless:true, args:['--no-sandbox','--disable-dev-shm-usage']});
const errors = [];
let checks = 0;
const check = (condition, message) => {assert.ok(condition, message); checks++;};
const pause = p => p.waitForTimeout(260); // Let the page transition finish before screenshots.
const button = (p,name) => p.getByRole('button',{name,exact:true});
async function type(p,field,value){await field.click({force:true});await p.keyboard.press('Control+A');await p.keyboard.type(value);await p.keyboard.press('Tab');}
async function nav(p,name){await button(p,name).click({force:true});await pause(p);}
async function token(p){const v=await p.evaluate(()=>localStorage.getItem('flutter.relay_session'));try{return JSON.parse(v);}catch{return v;}}
async function api(p,path){const r=await p.request.get(base+'/api'+path,{headers:{Authorization:'Bearer '+await token(p)}});assert.equal(r.status(),200,await r.text());return r.json();}
async function choose(p,current,choice){await button(p,current).click({force:true});await button(p,choice).last().click({force:true});await pause(p);}
async function menu(p,index,choice){await p.getByRole('button',{name:'More actions',exact:true}).nth(index).click({force:true});await button(p,choice).last().click({force:true});await pause(p);}
async function remove(p,index){await menu(p,index,'Delete');await button(p,'Delete').click({force:true});await pause(p);}

try {
  const p = await browser.newPage({viewport:{width:1440,height:1000},acceptDownloads:true});
  p.on('pageerror',e=>errors.push(e.message));
  p.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  await p.goto(base);
  await button(p,'New campaign').waitFor({timeout:30000});
  await pause(p);
  let data = await api(p,'/dashboard');
  check(data.total_contacts === 2486 && data.messages_sent >= 7558,'Seeded dashboard is database-backed');
  await p.screenshot({path:artifacts+'/dashboard.png'});
  await p.reload();await button(p,'New campaign').waitFor();
  check((await api(p,'/auth/me')).demo === true,'Demo session survives reload');

  for (const [name,file,wait] of [['Contacts','contacts','Add contact'],['Contact groups','groups','New group'],['Templates','templates','New template'],['Analytics','analytics','Export report']]) {
    await nav(p,name);await button(p,wait).waitFor();await pause(p);
    await p.screenshot({path:artifacts+'/'+file+'.png'});
    checks++;
  }
  // Exercise real registration rather than injecting session state.
  await nav(p,'Settings');await button(p,'Sign out').click({force:true});
  await button(p,'Create an account').waitFor();await button(p,'Create an account').click({force:true});
  const email='qa_'+Date.now()+'@test.example';
  await type(p, p.getByRole('textbox',{name:'Alex Morgan',exact:true}), 'Quinn');
  await type(p, p.getByRole('textbox',{name:'e.g. Acme Studio',exact:true}), 'QA Studio');
  await type(p, p.getByRole('textbox',{name:'you@company.com',exact:true}), email);
  await button(p,'Show password').click({force:true});
  await type(p, p.getByRole('textbox',{name:'Create a password',exact:true}), 'RelayTest@123');
  await button(p,'Hide password').click({force:true});
  await button(p,'Create your workspace').click({force:true});
  await button(p,'New campaign').waitFor();
  check((await api(p,'/auth/me')).demo === false,'Registration creates a private workspace');
  check((await api(p,'/contacts')).total===0,'New workspaces have meaningful empty states');
  console.log('✓ Authentication, session persistence, seeded screens, private workspace');

  await nav(p,'Contact groups');await button(p,'New group').click({force:true});
  await type(p, p.getByRole('textbox',{name:'e.g. Abuja founders',exact:true}), 'QA founders');
  await type(p, p.getByRole('textbox',{name:'What brings this community together?',exact:true}), 'A fictional, consented test audience.');
  await button(p,'Create group').click({force:true});await pause(p);
  let groups=(await api(p,'/groups')).items;
  check(groups.length===1,'Group creation persists');
  const gid=groups[0].id;

  await nav(p,'Contacts');await button(p,'Add contact').click({force:true});
  await type(p, p.getByRole('textbox',{name:'Amara',exact:true}), 'Nora');
  await type(p, p.getByRole('textbox',{name:'Okafor',exact:true}), 'Adeyemi');
  await type(p, p.getByRole('textbox',{name:'+234 803 123 4567',exact:true}), '+12025550142');
  await type(p, p.getByRole('textbox',{name:'amara@example.com',exact:true}), 'nora@demo.example');
  await choose(p,'No group','QA founders');
  await choose(p,'Pending opt-in','Opted in');
  await type(p, p.getByRole('textbox',{name:'Where did this person opt in?',exact:true}), 'Fictional QA consent form');
  await p.getByRole('checkbox').click({force:true});
  await expect(p.getByRole('checkbox')).toHaveAttribute('aria-checked','true');
  await button(p,'Add contact').click({force:true});await pause(p);
  let contacts=await api(p,'/contacts');
  check(contacts.total===1&&contacts.items[0].consent_status==='opted_in','Contact creation records opt-in');
  check(contacts.items[0].is_demo===true,'Reserved sample numbers cannot be sent live');

  await button(p,'Import contacts').click({force:true});
  const fileChooser=p.waitForEvent('filechooser');
  await button(p,'Choose CSV file').click({force:true});
  const chooser=await fileChooser;
  await chooser.setFiles({name:'qa-members.csv',mimeType:'text/csv',buffer:Buffer.from('first_name,last_name,phone,email,consent_status\nAmara,Okafor,+12025550101,amara@demo.example,opted_in\nDavid,Chen,+12025550102,david@demo.example,opted_in\nSarah,Johnson,+12025550103,sarah@demo.example,pending\n')});
  await button(p,'Import 3 contacts').waitFor();
  await choose(p,'No group · all contacts','QA founders');
  await p.getByRole('checkbox').click({force:true});
  await expect(p.getByRole('checkbox')).toHaveAttribute('aria-checked','true');
  await type(p, p.getByRole('textbox',{name:'e.g. event registration form, October 2026',exact:true}), 'Fictional QA opt-in manifest');
  await p.screenshot({path:artifacts+'/import-review.png'});
  await button(p,'Import 3 contacts').click({force:true});await pause(p);
  contacts=await api(p,'/contacts');
  check(contacts.total===4 && contacts.counts.opted_in===3 && contacts.counts.pending===1,'CSV upload, review, group assignment, and consent gates work');
  check((await api(p,'/groups')).items[0].total===4,'Imported members persist in their selected group');

  await button(p,'Save to phone').click({force:true});
  const downloadPromise=p.waitForEvent('download');
  await button(p,'Download vCard').click({force:true});
  const download=await downloadPromise;
  check(download.suggestedFilename()==='relay-contacts.vcf','Bulk vCard is downloaded');
  const downloadPath=await download.path();
  const vcf=await fs.readFile(downloadPath,'utf8');
  check((vcf.match(/BEGIN:VCARD/g)||[]).length===4,'Single vCard contains all selected group contacts');
  console.log('✓ Groups, contact CRUD, consented CSV upload, bulk contact saving');

  await nav(p,'Templates');await button(p,'New template').click({force:true});
  await type(p, p.getByRole('textbox',{name:'e.g. A little thank-you',exact:true}), 'QA welcome');
  await type(p, p.getByRole('textbox').nth(2), 'Hello {{1}}, welcome to our test community. Reply STOP to opt out.');
  await button(p,'Create template').click({force:true});await pause(p);
  check((await api(p,'/templates')).items.length===1,'Template creation persists');

  await nav(p,'Campaigns');await button(p,'New campaign').click({force:true});
  await type(p, p.getByRole('textbox',{name:'e.g. Weekend flash sale',exact:true}), 'QA hello');
  await choose(p,'All opted-in contacts','QA founders · 3');
  await p.screenshot({path:artifacts+'/campaign-builder.png'});
  await button(p,'Run demo campaign').click({force:true});
  await expect.poll(async()=>{const rows=(await api(p,'/campaigns')).items;return rows.find(r=>r.name==='QA hello')?.status;},{timeout:12000}).toBe('Completed');
  let campaign=(await api(p,'/campaigns')).items.find(r=>r.name==='QA hello');
  check(campaign.total===3,'Campaign excludes the pending contact');
  check(campaign.mode==='demo'&&campaign.delivered===3,'Simulated campaign receipts persist without real delivery');
  await button(p,'Refresh workspace').click({force:true});await pause(p);
  await menu(p,1,'Duplicate');
  check((await api(p,'/campaigns')).items.length===2,'Campaign duplication creates a new draft');
  await menu(p,1,'Edit');
  await type(p, p.getByRole('textbox').nth(0), 'QA draft revised');
  await button(p,'Save draft').click({force:true});await pause(p);
  check((await api(p,'/campaigns')).items.some(r=>r.name==='QA draft revised'),'Unsent campaign can be edited');
  await remove(p,1);
  check((await api(p,'/campaigns')).items.length===1,'Optimistic campaign deletion persists');
  const reportPromise=p.waitForEvent('download');await button(p,'Export report').click({force:true});
  check((await reportPromise).suggestedFilename()==='relay-campaign-report.csv','Campaign CSV reports download');
  console.log('✓ Templates, campaign creation, personalized demo delivery, duplication, editing, deletion, report export');

  await nav(p,'Contacts');await menu(p,1,'Edit');
  await type(p, p.getByRole('textbox').nth(0), 'Nora Updated');
  await button(p,'Save changes').click({force:true});await pause(p);
  check((await api(p,'/contacts')).items.some(r=>r.first_name==='Nora Updated'),'Contact edits persist');
  await remove(p,1);
  check((await api(p,'/contacts')).total===3,'Optimistic contact deletion persists');

  await nav(p,'Templates');await menu(p,1,'Edit');
  await type(p, p.getByRole('textbox').nth(0), 'QA welcome refined');
  await button(p,'Save changes').click({force:true});await pause(p);
  check((await api(p,'/templates')).items[0].title==='QA welcome refined','Template edits persist');
  await remove(p,1);
  check((await api(p,'/templates')).items.length===0,'Template deletion preserves campaign message history');

  await nav(p,'Contact groups');await menu(p,1,'Edit');
  await type(p, p.getByRole('textbox').nth(0), 'QA founders revised');
  await button(p,'Save changes').click({force:true});await pause(p);
  check((await api(p,'/groups')).items[0].name==='QA founders revised','Group edits persist');
  await remove(p,1);
  check((await api(p,'/groups')).items.length===0 && (await api(p,'/contacts')).total===3,'Group deletion keeps contacts');

  await nav(p,'Settings');
  await type(p, p.getByRole('textbox').nth(1), 'QA Studio updated');
  await button(p,'Save changes').click({force:true});await pause(p);
  check((await api(p,'/auth/me')).workspace==='QA Studio updated','Workspace preferences persist');
  await button(p,'Sign out').click({force:true});await button(p,'Sign in').waitFor();
  await type(p, p.getByRole('textbox',{name:'you@company.com',exact:true}), email);
  await button(p,'Show password').click({force:true});
  await type(p, p.getByRole('textbox',{name:'Enter your password',exact:true}), 'RelayTest@123');
  await button(p,'Hide password').click({force:true});await button(p,'Sign in').click({force:true});await button(p,'New campaign').waitFor();
  check((await api(p,'/auth/me')).workspace==='QA Studio updated','Existing account signs in with persisted data');
  console.log('✓ Full core-resource CRUD, settings persistence, sign-out and sign-in');

  const mobile=await browser.newPage({viewport:{width:390,height:844},acceptDownloads:true});
  mobile.on('pageerror',e=>errors.push(e.message));
  await mobile.goto(base);await button(mobile,'New campaign').waitFor();await pause(mobile);
  await mobile.screenshot({path:artifacts+'/mobile.png'});
  await button(mobile,'Open navigation').click({force:true});await pause(mobile);
  await button(mobile,'Contact groups').click({force:true});await button(mobile,'New group').waitFor();await pause(mobile);
  await mobile.screenshot({path:artifacts+'/mobile-groups.png'});
  check((await api(mobile,'/groups')).items.length===6,'Mobile navigation and seeded group page work');
  check(errors.length===0,'No browser runtime errors: '+errors.join('; '));
  console.log(`\n${checks} end-to-end checks passed. Screenshots saved to ${artifacts}.`);
} catch(e) {
  const pages=browser.contexts().flatMap(c=>c.pages());
  if(pages.length){const last=pages.at(-1); await last.screenshot({path:artifacts+'/failure.png'}); console.log((await last.locator('body').ariaSnapshot()).slice(-4500));}
  throw e;
} finally {
  await browser.close();
}
