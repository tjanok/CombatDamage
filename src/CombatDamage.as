/*
    CombatDamage.as
    Original AMXX Plugin Author: YoshiokaHaruki
    Modified by: Drak

    Unlike the original plugin, this script does not limit the visibility of the damage indicators to the attacker
    CS has EF_OWNER_VISIBILITY flag for that, but Sven Co-op does not support it.

    NOTE: Pretty sure we can use AddToFullPack
*/

#include "inc/Utility"

array<string> models = {
    "models/x_re/floating_damage_sc.mdl"
};

// ConVars
CCVar@ CvarEnabled;
CCVar@ CvarSkinType;
CCVar@ CvarPlayers;
CCVar@ CvarUprightOnly;
CCVar@ CvarSkinTypePlayers;
CCVar@ CvarNumberOfEnts;
CCVar@ CvarDecayTime;

const int MAX_BODY_PARTS = 4;
const int MAX_SUBMODELS = 11;
const int ASCII_ZERO = 48;

const int CLOSE_RANGE_THRESHOLD = 100;
const int ORIGIN_OFFSET_SIZE = 25;

array<int> MAX_BODY_SUBMODELS = {
    MAX_SUBMODELS, MAX_SUBMODELS, MAX_SUBMODELS, MAX_SUBMODELS
};

void PluginInit()
{
    g_Module.get_ScriptInfo().SetAuthor( "YoshiokaHaruki / Drak" );
    g_Module.get_ScriptInfo().SetContactInfo( "https://github.com/tjanok" );

	g_Hooks.RegisterHook( Hooks::Player::PlayerTakeDamage, @PlayerTakeDamage );
    g_Hooks.RegisterHook( Hooks::Monster::MonsterTakeDamage, @MonsterTakeDamage );

    // Convars
    @CvarEnabled = CCVar( "enabled", 1, "enables combat damage", ConCommandFlag::AdminOnly );
    @CvarSkinType = CCVar( "skin", 18, "sets skin type for monsters", ConCommandFlag::AdminOnly );
    @CvarSkinTypePlayers = CCVar( "skin_players", 19, "sets skin type for players", ConCommandFlag::AdminOnly );
    @CvarPlayers = CCVar( "players", 1, "shows combat damage for players (and monsters)", ConCommandFlag::AdminOnly );
    @CvarUprightOnly = CCVar( "upright_only", 0, "damage appears upright, no rotation", ConCommandFlag::AdminOnly );
    @CvarNumberOfEnts = CCVar( "max_meters", 8, "maximum number of damage indicators", ConCommandFlag::AdminOnly );
    @CvarDecayTime = CCVar( "decay_time", 10, "how fast damage indicators fade out", ConCommandFlag::AdminOnly );
}


// Prepare body value from damage
int PrepareBody( float flDamage )
{
    flDamage = Math.min( flDamage, 9999.0 );
    
    string szDamage = formatFloat( flDamage, "", 0, 0 ); // Convert to integer string
    array<int> aParts;
    aParts.resize( MAX_BODY_PARTS );
    
    // Initialize array with zeros
    for( uint i = 0; i < MAX_BODY_PARTS; i++ )
    {
        aParts[i] = 0;
    }

    
    // Convert each digit character to integer and increment by 1
    for( uint i = 0; i < szDamage.Length() && i < MAX_BODY_PARTS; i++ )
    {
        aParts[i] = int( szDamage[i] ) - ASCII_ZERO + 1;
    }
    
    return CalculateModelBodyArr( aParts, MAX_BODY_SUBMODELS, MAX_BODY_PARTS );
}

// Calculate model body value from parts array
int CalculateModelBodyArr( array<int>& parts, array<int>& sizes, int count )
{
    int bodyInt32 = 0;
    int tempCount = count;
    
    while( tempCount-- > 0 )
    {
        if( sizes[tempCount] == 1 )
            continue;
        
        int temp = parts[tempCount];
        for( int it = 0; it < tempCount; it++ )
        {
            temp *= sizes[it];
        }
        
        bodyInt32 += temp;
    }
    
    return bodyInt32;
}

void MapInit()
{
    RegisterFloatingDamage();

    // Precache models
    for( uint i = 0; i < models.length(); i++ )
    {
        g_Game.PrecacheModel( models[i] );
    }
}

HookReturnCode MapChange()
{
    g_CustomEntityFuncs.UnRegisterCustomEntity( "floating_damage" );
	return HOOK_CONTINUE;
}

void CheckForExistingEntites( EHandle pPlayerEntity )
{
    if( !pPlayerEntity )
        return;

    CBaseEntity@ pPlayer = pPlayerEntity.GetEntity();
    array<CBaseEntity@> existingEntities = 
        FindEntitiesByOwner( "floating_damage", pPlayer.edict() );

    if( existingEntities.length() >= CvarNumberOfEnts.GetInt() )
    {
        // Remove oldest entity
        CBaseEntity@ oldestEnt = existingEntities[0];
        float oldestTime = oldestEnt.pev.spawnflags; // Using spawnflags to store spawn time temporarily

        for( uint i = 1; i < existingEntities.length(); i++ )
        {
            CBaseEntity@ ent = existingEntities[i];
            float entTime = ent.pev.spawnflags;
            if( entTime < oldestTime )
            {
                oldestTime = entTime;
                @oldestEnt = ent;
            }
        }

        if( oldestEnt !is null )
        {
            g_EntityFuncs.Remove( oldestEnt );
        }
    }
}

HookReturnCode PlayerTakeDamage( DamageInfo@ pDamageInfo )
{
    if( !CvarEnabled.GetBool() )
        return HOOK_CONTINUE;

    if( !CvarPlayers.GetBool() )
        return HOOK_CONTINUE;

    CBaseEntity@ victim = pDamageInfo.pVictim;
    CBaseEntity@ attacker = pDamageInfo.pAttacker;

    if( victim is null || attacker is null )
        return HOOK_CONTINUE;
    
    float damage = pDamageInfo.flDamage;
    if( damage < 1 )
        return HOOK_CONTINUE;
    
    CBaseEntity@ castedEntity = cast<CBaseEntity@>( attacker );
    int bitsDamageType = pDamageInfo.bitsDamageType;

    if( victim.IsAlive() == false )
        return HOOK_CONTINUE;

    Vector origin = 
        GetDamagePosition( EHandle( castedEntity ), EHandle( victim ), victim.pev.origin );

    CheckForExistingEntites( EHandle( castedEntity ) );

    if( victim.IsPlayer() )
    {
        // slight offset for players, to not obstruct our view
        origin.z += 30.0;
    }

    // If victim is a player and attacker is not, show damage from victim's perspective
    if( victim.IsPlayer() && !attacker.IsPlayer() )
    {
        @castedEntity = victim;
    }

    CBaseEntity@ ent = 
        CreateDamageEntity( origin, damage, castedEntity.edict(), false );

    return HOOK_CONTINUE;
}

HookReturnCode MonsterTakeDamage( DamageInfo@ pDamageInfo )
{
    if( !CvarEnabled.GetBool() )
        return HOOK_CONTINUE;

    CBaseEntity@ victim = pDamageInfo.pVictim ;
    CBaseEntity@ attacker =  pDamageInfo.pAttacker ;

    if( victim is null || attacker is null )
        return HOOK_CONTINUE;
    
    float damage = pDamageInfo.flDamage;
    if( damage < 1 )
        return HOOK_CONTINUE;

    if( victim.IsAlive() == false )
        return HOOK_CONTINUE;

    if( victim.IsPlayer() )
        return HOOK_CONTINUE;
    
    int bitsDamageType = pDamageInfo.bitsDamageType;

    CBaseEntity@ castedEntity = attacker;

    Vector origin = 
        GetDamagePosition( EHandle( castedEntity ), EHandle( victim ), victim.pev.origin );

    CheckForExistingEntites( EHandle( castedEntity ) );

    CBaseEntity@ ent = 
        CreateDamageEntity( origin, damage, castedEntity.edict(), true );
    
    return HOOK_CONTINUE;
}


// Calculate damage position based on attacker and victim
Vector GetDamagePosition( EHandle pPlayerEntity, EHandle pVictimEntity, Vector vecVictimOrigin )
{
    if( !pPlayerEntity || !pVictimEntity )
        return vecVictimOrigin;

    CBaseEntity@ pPlayer = pPlayerEntity.GetEntity();
    CBaseEntity@ pVictim = pVictimEntity.GetEntity();

    Vector vecAttackerOrigin = pPlayer.pev.origin;
    
    // Calculate distance between attacker and victim
    float distance = ( vecAttackerOrigin - vecVictimOrigin ).Length();
    
    // Get direction from victim to attacker
    Vector vecDirection = vecAttackerOrigin - vecVictimOrigin;
    vecDirection = vecDirection.Normalize();
    
    // Get victim's view offset and add 15 units up
    Vector vecViewOfs = pVictim.pev.view_ofs;
    vecViewOfs.z += 15.0;
    
    // If we're close (within melee range), push damage text backwards
    const float offsetDistance = 20.0;
    float pushDistance = offsetDistance;

    if( distance < CLOSE_RANGE_THRESHOLD )
    {
        pushDistance = -offsetDistance;
    }

    Vector vecOut = vecVictimOrigin + vecViewOfs;
    vecOut = vecOut + ( vecDirection * pushDistance );
    
    return vecOut;
}
float CalculateBodyOffset( float damage )
{
    const float DIGIT_WIDTH = 12.5;
    
    string szDamage = formatFloat( damage, "", 0, 0 );
    int digitCount = int( szDamage.Length() );
    
    if( digitCount == 0 || digitCount >= 4 )
        return 0.0; // Centered or max width
    
    // Calculate offset based on how many digits are missing on the left
    // If 1 digit: offset right by 1.5 digits
    // If 2 digits: offset right by 1.0 digits  
    // If 3 digits: offset right by 0.5 digits
    float missingDigits = 4.0 - float( digitCount );
    float offset = ( missingDigits * 0.5 ) * DIGIT_WIDTH;
    
    return offset;
}

// Create a custom entity class
class CFloatingDamage : ScriptBaseEntity
{
    // Owner is the inflictor of the damage
    edict_t@ m_pOwner;
    
    float m_fStartingDamage = 0;
    float m_fCurrentDamage = 0;
    
    int skin = 0;
    
    bool KeyValue( const string& in szKey, const string& in szValue )
    {
        return BaseClass.KeyValue( szKey, szValue );
    }
    
    void Spawn()
    {
        Precache();
        
        g_EntityFuncs.SetModel( self, models[0] );
        g_EntityFuncs.SetSize( self.pev, Vector( -16, -16, -16 ), Vector( 16, 16, 16 ) );
        
        @self.pev.owner = m_pOwner;
        self.pev.solid = SOLID_NOT;
        self.pev.movetype = MOVETYPE_NOCLIP;
        self.pev.rendermode = kRenderTransAdd;
        self.pev.renderamt = 255;
        self.pev.spawnflags = g_Engine.time; // Store spawn time in spawnflags for tracking
        self.pev.skin = skin;
        self.pev.body = PrepareBody( m_fCurrentDamage );
        self.pev.scale = 1.0;

        if( m_pOwner !is null )
        {
            CBaseEntity@ castedEntity = g_EntityFuncs.Instance( m_pOwner );
            if( castedEntity !is null )
            {
                // Get player's view angles FIRST (before setting entity angles)
                Vector playerAngs = castedEntity.pev.v_angle;
                
                // Calculate offset based on PLAYER'S view direction
                float xOffset = CalculateBodyOffset( m_fCurrentDamage );
                
                // Make vectors from PLAYER'S angles to get correct right vector
                Math.MakeVectors( playerAngs );
                Vector playerRight = g_Engine.v_right;
                
                // Apply offset in player's right direction
                self.pev.origin = self.pev.origin + ( playerRight * xOffset );
                
                // NOW set entity to face player (after offset is applied)
                playerAngs.y -= 180.0;
                self.pev.angles = playerAngs;

                if( !CvarUprightOnly.GetBool() )
                {
                    self.pev.angles.z = Math.RandomFloat( -15.0, 15.0 );
                }

                Vector randomOffset = self.pev.origin;
                randomOffset.x += Math.RandomFloat( -ORIGIN_OFFSET_SIZE, ORIGIN_OFFSET_SIZE );
                randomOffset.y += Math.RandomFloat( -ORIGIN_OFFSET_SIZE, ORIGIN_OFFSET_SIZE );
                randomOffset.z += Math.RandomFloat( -ORIGIN_OFFSET_SIZE, ORIGIN_OFFSET_SIZE );
                
                // Check if random offset will hit walls
                TraceResult tr;
                g_Utility.TraceLine(
                    self.pev.origin,
                    randomOffset,
                    ignore_monsters,
                    self.edict(),
                    tr
                );
                
                if( tr.flFraction >= 0.8 )
                {
                    self.pev.origin = randomOffset;
                }
            }
        }

        SetThink( ThinkFunction( this.Think ) );
        self.pev.nextthink = g_Engine.time + 0.05;
    }
    
    void Precache()
    {
        g_Game.PrecacheModel( models[0] );
    }
    
    void Think()
    {
        self.pev.renderamt -= CvarDecayTime.GetFloat();
        
        if( self.pev.renderamt <= 15.0 )
        {
            g_EntityFuncs.Remove( self );
            return;
        }

        // Float upwards
        self.pev.origin.z += 0.5;

        // Scale smaller as we travel upwards
        float scaleFactor = self.pev.renderamt / 255.0;
        self.pev.scale = scaleFactor;

        if( m_fCurrentDamage != m_fStartingDamage )
        {
            self.pev.body = PrepareBody( m_fCurrentDamage );
        }

        self.pev.nextthink = g_Engine.time + 0.09;
    }
}

void RegisterFloatingDamage()
{
    g_CustomEntityFuncs.RegisterCustomEntity( "CFloatingDamage", "floating_damage" );
}

CBaseEntity@ CreateDamageEntity( Vector origin, float damage, edict_t@ owner = null, bool isMonster = false )
{
    CBaseEntity@ ent = g_EntityFuncs.CreateEntity( "floating_damage", null, false );
    CFloatingDamage@ damager = cast<CFloatingDamage@>( g_EntityFuncs.CastToScriptClass( ent ) );
    
    if( damager !is null )
    {
        damager.m_fCurrentDamage = damage;
        damager.m_fStartingDamage = damage;
        damager.skin = isMonster ? CvarSkinType.GetInt() : CvarSkinTypePlayers.GetInt();
        @damager.m_pOwner = owner;
        g_EntityFuncs.SetOrigin( ent, origin );
        g_EntityFuncs.DispatchSpawn( ent.edict() );
    }

    return ent;
}