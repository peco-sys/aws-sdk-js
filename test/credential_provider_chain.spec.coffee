helpers = require('./helpers')
AWS = helpers.AWS

if AWS.util.isNode()
  describe 'AWS.CredentialProviderChain', ->
    describe 'resolve', ->
      chain = null
      defaultProviders = AWS.CredentialProviderChain.defaultProviders

      beforeEach (done) ->
        process.env = {}
        chain = new AWS.CredentialProviderChain [
          -> new AWS.EnvironmentCredentials('AWS'),
          -> new AWS.EnvironmentCredentials('AMAZON')
        ]
        done()

      afterEach ->
        AWS.CredentialProviderChain.defaultProviders = defaultProviders
        process.env = {}

      it 'returns an error by default', ->
        chain.resolve (err) ->
          expect(err.message).to.equal('Variable AMAZON_ACCESS_KEY_ID not set.')

      it 'returns AWS-prefixed credentials found in ENV', ->

        process.env['AWS_ACCESS_KEY_ID'] = 'akid'
        process.env['AWS_SECRET_ACCESS_KEY'] = 'secret'
        process.env['AWS_SESSION_TOKEN'] = 'session'

        chain.resolve (err, creds) ->
          expect(creds.accessKeyId).to.equal('akid')
          expect(creds.secretAccessKey).to.equal('secret')
          expect(creds.sessionToken).to.equal('session')

      it 'returns AMAZON-prefixed credentials found in ENV', ->

        process.env['AMAZON_ACCESS_KEY_ID'] = 'akid'
        process.env['AMAZON_SECRET_ACCESS_KEY'] = 'secret'
        process.env['AMAZON_SESSION_TOKEN'] = 'session'

        chain.resolve (err, creds) ->
          expect(creds.accessKeyId).to.equal('akid')
          expect(creds.secretAccessKey).to.equal('secret')
          expect(creds.sessionToken).to.equal('session')

      it 'prefers AWS credentials to AMAZON credentials', ->

        process.env['AWS_ACCESS_KEY_ID'] = 'akid'
        process.env['AWS_SECRET_ACCESS_KEY'] = 'secret'
        process.env['AWS_SESSION_TOKEN'] = 'session'

        process.env['AMAZON_ACCESS_KEY_ID'] = 'akid2'
        process.env['AMAZON_SECRET_ACCESS_KEY'] = 'secret2'
        process.env['AMAZON_SESSION_TOKEN'] = 'session2'

        chain.resolve (err, creds) ->
          expect(creds.accessKeyId).to.equal('akid')
          expect(creds.secretAccessKey).to.equal('secret')
          expect(creds.sessionToken).to.equal('session')

      it 'uses the defaultProviders property on the constructor', ->

        # remove default providers
        AWS.CredentialProviderChain.defaultProviders = []

        # these should now get ignored
        process.env['AWS_ACCESS_KEY_ID'] = 'akid'
        process.env['AWS_SECRET_ACCESS_KEY'] = 'secret'
        process.env['AWS_SESSION_TOKEN'] = 'session'

        chain = new AWS.CredentialProviderChain()
        chain.resolve (err) ->
          expect(err.message).to.equal('No providers')

      it 'calls resolve on each provider in the chain, stopping for akid', ->
        staticCreds = accessKeyId: 'abc', secretAccessKey: 'xyz'
        chain = new AWS.CredentialProviderChain([staticCreds])
        chain.resolve (err, creds) ->
          expect(creds.accessKeyId).to.equal('abc')
          expect(creds.secretAccessKey).to.equal('xyz')
          expect(creds.sessionToken).to.equal(undefined)

      it 'accepts providers as functions, elavuating them during resolution', ->
        provider = ->
          accessKeyId: 'abc', secretAccessKey: 'xyz'
        chain = new AWS.CredentialProviderChain([provider])
        chain.resolve (err, creds) ->
          expect(creds.accessKeyId).to.equal('abc')
          expect(creds.secretAccessKey).to.equal('xyz')
          expect(creds.sessionToken).to.equal(undefined)

    if typeof Promise == 'function'
      describe 'resolvePromise', ->
        [err, creds, chain, forceError] = []

        thenFunction = (c) ->
          creds = c

        catchFunction = (e) ->
          err = e

        mockProvider = ->
          provider = new helpers.MockCredentialsProvider()
          if forceError
            provider.forceRefreshError = true
          provider

        before ->
          AWS.config.setPromisesDependency()

        beforeEach ->
          err = null
          creds = null
          chain = new AWS.CredentialProviderChain([mockProvider])

        it 'resolves when creds successfully retrieved from a provider in the chain', ->
          forceError = false
          # if a promise is returned from a test, then done callback not needed
          # and next test will wait for promise to resolve before running
          return chain.resolvePromise().then(thenFunction).catch(catchFunction).then ->
            expect(err).to.be.null
            expect(creds).to.not.be.null
            expect(creds.accessKeyId).to.equal('akid')
            expect(creds.secretAccessKey).to.equal('secret')

        it 'rejects when all providers in chain return an error', ->
          forceError = true
          return chain.resolvePromise().then(thenFunction).catch(catchFunction).then ->
            expect(err).to.not.be.null
            expect(err.code).to.equal('MockCredentialsProviderFailure')
            expect(creds).to.be.null
