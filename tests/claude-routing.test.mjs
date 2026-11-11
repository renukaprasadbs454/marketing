import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {claudeRoute,stageOneQuestions,gateStageOne} from '../core/agent/router.mjs';

test('Claude routing parses a read-only chat route and removes its isolated directory',async()=>{
 let dir;
 const result=await claudeRoute({message:'hi'},stageOneQuestions(['talk']),async(prompt,options)=>{
  dir=options.cwd;
  assert.ok(fs.existsSync(dir));
  assert.equal(options.talk,true);
  assert.match(prompt,/hi/);
  return JSON.stringify({group:{choice:'talk',confidence:0.95,probabilities:{talk:0.95,ask:0.05}},act:0,forbidden:0,single:1});
 });
 assert.deepEqual(gateStageOne(result,[]),{type:'talk'});
 assert.equal(fs.existsSync(dir),false);
});

test('Claude routing cleans up after invalid model output',async()=>{
 let dir;
 await assert.rejects(claudeRoute({},stageOneQuestions(['talk']),async(_prompt,options)=>{dir=options.cwd;return 'invalid';}),/JSON/);
 assert.equal(fs.existsSync(dir),false);
});
