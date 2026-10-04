import assert from 'node:assert/strict'
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
const path = fileURLToPath(new URL('../opencode/.config/opencode/plugins/model-fallback.js', import.meta.url))
const { ModelFallbackPlugin } = await import('data:text/javascript;base64,' + readFileSync(path).toString('base64'))
const cfgPath = `${process.env.HOME}/.local/config/opencode-models.json`
writeFileSync(cfgPath, JSON.stringify({free_models: ['opencode/a-free', 'opencode/b-free', 'paid/model', null]}))
let now = 100000000
Date.now = () => now
const initial = () => ({info: {id:'user1', role:'user', agent:'reviewer', model:{providerID:'opencode',modelID:'a-free'},tools:{bash:false},system:'keep this'},parts:[{type:'text',text:'review'},{type:'file',url:'file:///fixture',mime:'text/plain'}]})
let messages = [initial()], prompts = [], aborts = 0, failAbort = false
let plugin
const client = {
  session: {
    messages: async () => ({data: messages}),
    abort: async () => {
      aborts++
      if (failAbort) throw new Error('failed')
      await plugin.event({event:{type:'session.idle',properties:{sessionID:'s'}}})
    },
    promptAsync: async ({body}) => {
      prompts.push(body)
      messages.push({info:{...body,id:`retry${prompts.length}`,role:'user'},parts:body.parts})
      return {data:undefined}
    },
  },
  app: {log: async () => {}}, tui: {showToast: async () => {}},
}
const event = (error) => plugin.event({event:{type:'session.error',properties:{sessionID:'s',error}}})
const error = {name:'APIError',data:{statusCode:429,message:'rate limit'}}
plugin = await ModelFallbackPlugin({client})
await Promise.all([event(error), event(error)])
assert.equal(prompts.length,1, 'overlapping errors must coalesce')
assert.equal(aborts,1)
assert.equal(prompts[0].agent,'reviewer')
assert.deepEqual(prompts[0].tools,{bash:false})
assert.equal(prompts[0].system,'keep this')
assert.equal(prompts[0].model.modelID,'b-free')
assert.equal(messages[0].parts[1].type,'file', 'original attachments remain in history')
assert.notEqual(prompts[0].parts[0].text,'review', 'do not repeat the original task')
// Advance beyond cooldowns: abort/idle must never reset the per-user retry cap.
for (let i=0;i<8;i++) { now += 7*60*60*1000; await event(error) }
assert.equal(prompts.length,4)
messages.push({...initial(),info:{...initial().info,id:'user2'}})
now += 7*60*60*1000
await event(error)
assert.equal(prompts.length,5, 'a new user request gets a fresh retry budget')
for (const name of ['MessageAbortedError','ProviderAuthError']) {
  now += 7*60*60*1000
  await event({name,data:{message:'quota exceeded',statusCode:429}})
}
await event({name:'APIError',data:{statusCode:401,message:'quota'}})
assert.equal(prompts.length,5)
failAbort = true; now += 7*60*60*1000; await event(error)
assert.equal(prompts.length,5, 'do not start a concurrent prompt after a failed abort')
// SDK failure/completion events may be late; a finished turn must not restart.
failAbort = false
messages.push({info:{role:'assistant',parentID:messages.at(-1).info.id,finish:'stop'}})
now += 7*60*60*1000; await event(error)
assert.equal(prompts.length,5)
process.env.DOTFILES_OPENCODE_NO_FALLBACK='1'
assert.deepEqual(await ModelFallbackPlugin({client}),{})
delete process.env.DOTFILES_OPENCODE_NO_FALLBACK
mkdirSync(`${process.env.HOME}/.local/state/agents`,{recursive:true})
writeFileSync(`${process.env.HOME}/.local/state/agents/opencode-agent-models.json`,JSON.stringify({available:[]}))
plugin = await ModelFallbackPlugin({client}); messages=[initial()]
await event(error)
assert.equal(prompts.length,5,'an empty verified catalog must not reactivate stale fallback seeds')
console.log('fallback regression scenarios passed')
