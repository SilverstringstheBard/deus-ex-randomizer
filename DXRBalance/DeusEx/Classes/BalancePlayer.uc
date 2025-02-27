class BalancePlayer injects Human;

function TakeDamage(int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType)
{

    if(damageType == 'NanoVirus') {
        RandomizeAugStates();
    }
    Super.TakeDamage(Damage, instigatedBy, hitlocation, momentum, damageType);

}

function RandomizeAugStates()
{
    local Augmentation aug;
    local DXRBase dxrb;

    for(aug = AugmentationSystem.FirstAug; aug!=None; aug = aug.next){

        //Skip synthetic heart since deactivating it turns off all your augs
        //(Maybe this could only skip it for deactivation?)
        if (aug.bHasIt && !aug.bAlwaysActive && (AugHeartLung(aug)==None)) {
            if (rand(2)==0){
                if (aug.bIsActive){
                    aug.Deactivate();
                } else {
                    aug.Activate();
                }
            }
        }
    }
    AugmentationSystem.RefreshAugDisplay();
}

function float AdjustCritSpots(float Damage, name damageType, vector hitLocation)
{
    local vector offset;
    local float headOffsetZ, headOffsetY, armOffset;

    // EMP attacks drain BE energy
    if (damageType == 'EMP')
        return Damage;

    // use the hitlocation to determine where the pawn is hit
    // transform the worldspace hitlocation into objectspace
    // in objectspace, remember X is front to back
    // Y is side to side, and Z is top to bottom
    offset = (hitLocation - Location) << Rotation;

    // calculate our hit extents
    headOffsetZ = CollisionHeight * 0.78;
    headOffsetY = CollisionRadius * 0.35;
    armOffset = CollisionRadius * 0.35;

    // We decided to just have 3 hit locations in multiplayer MBCODE
    if (( Level.NetMode == NM_DedicatedServer ) || ( Level.NetMode == NM_ListenServer ))
    {
        // leave it vanilla
        return Damage;
    }

    // Normal damage code path for single player
    if (offset.z > headOffsetZ)     // head
    {
        // narrow the head region
        if ((Abs(offset.x) < headOffsetY) || (Abs(offset.y) < headOffsetY))
        {
            // do 1.6x damage instead of the 2x damage in DeusExPlayer.uc::TakeDamage()
            return Damage * 0.8;
        }
    }
    else if (offset.z < 0.0)        // legs
    {
    }
    else                            // arms and torso
    {
        if (offset.y > armOffset)
        {
            // right arm
        }
        else if (offset.y < -armOffset)
        {
            // left arm
        }
        else
        {
            // and finally, the torso! do 1.3x damage instead of the 2x damage in DeusExPlayer.uc::TakeDamage()
            return Damage * 0.65;
        }
    }

    return Damage;
}

function float ReduceEnviroDamage(float damage, name damageType)
{
    local float skillLevel, augLevel;

    if (damageType != 'TearGas' && damageType != 'PoisonGas' && damageType != 'Radiation'
        && damageType != 'HalonGas' && damageType != 'PoisonEffect' && damageType != 'Poison'
        && damageType != 'Flamed' && damageType != 'Burned' && damageType != 'Shocked' ) {
            return damage;
    }

    if (AugmentationSystem != None)
        augLevel = AugmentationSystem.GetAugLevelValue(class'AugEnviro');

    if (augLevel >= 0.0)
        damage *= augLevel;

    // get rid of poison if we're maxed out
    if (damage ~= 0.0)
    {
        StopPoison();
        drugEffectTimer -= 4;	// stop the drunk effect
        if (drugEffectTimer < 0)
            drugEffectTimer = 0;
    }

    if(damageType == 'PoisonEffect' || damageType == 'Poison') {
        return damage;
    }

    skillLevel = SkillSystem.GetSkillLevelValue(class'SkillEnviro');
    skillLevel = FClamp(skillLevel, 0, 1.1);

    if (UsingChargedPickup(class'HazMatSuit'))
    {
        damage *= 0.75 * skillLevel;
    }
    else // passive enviro skill still gives some damage reduction
    {
        damage *= 1.25 * skillLevel + 0.25;
    }

    return damage;
}

function float ArmorReduceDamage(float damage)
{
    local float skillLevel;

    // go through the actor list looking for owned BallisticArmor
    // since they aren't in the inventory anymore after they are used
    if (UsingChargedPickup(class'BallisticArmor'))
    {
        skillLevel = SkillSystem.GetSkillLevelValue(class'SkillEnviro');
        if(skillLevel < 0)
            skillLevel = 0;
        return damage * 0.5 * skillLevel;
    }
    return damage;
}

// ----------------------------------------------------------------------
// DXReduceDamage()
//
// Calculates reduced damage from augmentations and from inventory items
// Also calculates a scalar damage reduction based on the mission number
// ----------------------------------------------------------------------
function bool DXReduceDamage(int Damage, name damageType, vector hitLocation, out int adjustedDamage, bool bCheckOnly)
{
    local float newDamage, oldDamage;
    local float augLevel, skillLevel;
    local float pct;
    local HazMatSuit suit;
    local BallisticArmor armor;
    local bool bReduced;
    local float damageMult;

    bReduced = False;
    newDamage = Float(Damage);
    newDamage = AdjustCritSpots(newDamage, damageType, hitLocation);
    oldDamage = newDamage;

    newDamage = ReduceEnviroDamage(newDamage, damageType);

    if ((damageType == 'Shot') || (damageType == 'Sabot') || (damageType == 'Exploded') || (damageType == 'AutoShot'))
    {
        newDamage = ArmorReduceDamage(newDamage);
    }

    if (damageType == 'HalonGas')
    {
        if (bOnFire && !bCheckOnly)
            ExtinguishFire();
    }

    if ((damageType == 'Shot') || (damageType == 'AutoShot'))
    {
        if (AugmentationSystem != None)
            augLevel = AugmentationSystem.GetAugLevelValue(class'AugBallistic');

        if (augLevel >= 0.0)
            newDamage *= augLevel;
    }

    if (damageType == 'EMP')
    {
        if (AugmentationSystem != None)
            augLevel = AugmentationSystem.GetAugLevelValue(class'AugEMP');

        if (augLevel >= 0.0)
            newDamage *= augLevel;
    }

    if ((damageType == 'Burned') || (damageType == 'Flamed') ||
        (damageType == 'Exploded') || (damageType == 'Shocked'))
    {
        if (AugmentationSystem != None)
            augLevel = AugmentationSystem.GetAugLevelValue(class'AugShield');

        if (augLevel >= 0.0)
            newDamage *= augLevel;
    }

    //Apply damage multiplier
    //This gets tweaked from DXRandoCrowdControlLink, but will normally just be 1.0
    damageMult = GetDamageMultiplier();
    if (damageMult!=0) {
        newDamage*=damageMult;
    }

    // show resistance, don't factor in the random rounding, so the numbers are stable and easier to read
    pct = 1.0 - (newDamage / oldDamage);
    if (!bCheckOnly)
    {
        SetDamagePercent(pct);
    }
    if( pct > 0 ) {
        bReduced = True;
        ClientFlash(0.01, vect(0, 0, 50));
    }

    //
    // Reduce or increase the damage based on the combat difficulty setting, do this before SetDamagePercent for the UI display
    // because we don't want to show 100% damage reduction but then do the minimum of 1 damage
    if ((damageType == 'Shot') || (damageType == 'AutoShot') ||
        damageType == 'Flamed' || damageType == 'Burned')
    {
        newDamage *= CombatDifficulty;
        oldDamage *= CombatDifficulty;
    }
    else if (damageType != 'fell' && damageType != 'Drowned') {
        newDamage *= CombatDifficulty/2 + 0.2;
        oldDamage *= CombatDifficulty/2 + 0.2;
    }

    if(frand() < (newDamage%1.0)) {// DXRando: random rounding, 1.9 is more likely to round up than 1.1 is
        newDamage += 0.999;
        oldDamage += 0.999;
    }

    adjustedDamage = Int(newDamage);// adjustedDamage is our out param

    return bReduced;
}

function float GetDamageMultiplier()
{
    local DataStorage datastorage;
    datastorage = class'DataStorage'.static.GetObjFromPlayer(self);
    return float(datastorage.GetConfigKey('cc_damageMult'));
}

function CatchFire( Pawn burner )
{
    local bool doSetTimer;
    if (bOnFire==false && Region.Zone.bWaterZone==false)
        doSetTimer = true;

    Super.CatchFire(burner);

    // set the burn timer, tick the burn every 4 seconds instead of 1 so that the player can actually survive it
    if(doSetTimer)
        SetTimer(4.0, True);
}

simulated function DrugEffects(float deltaTime)
{
    local float olddrugEffectTimer;

    // set a cap on the effect strength separately from the duration
    olddrugEffectTimer = drugEffectTimer;
    drugEffectTimer = FMin( drugEffectTimer, 120.0 );
    Super.DrugEffects(deltaTime);

    // calculate duration myself
    drugEffectTimer = FMin(olddrugEffectTimer, 120.0 );
    drugEffectTimer -= deltaTime * 1.5;
    if (drugEffectTimer < 0)
        drugEffectTimer = 0;
}

// ----------------------------------------------------------------------
// HealPlayer()
// ----------------------------------------------------------------------

function int HealPlayer(int baseHealPoints, optional Bool bUseMedicineSkill)
{
    local int adjustedHealAmount;

    adjustedHealAmount = _HealPlayer(baseHealPoints, bUseMedicineSkill);

    if (adjustedHealAmount == 1)
        ClientMessage(Sprintf(HealedPointLabel, adjustedHealAmount));
    else if(adjustedHealAmount != 1)// we want messages for healing 0 so you know it could've healed you
        ClientMessage(Sprintf(HealedPointsLabel, adjustedHealAmount));

    return adjustedHealAmount;
}

function int _HealPlayer(int baseHealPoints, optional Bool bUseMedicineSkill, optional bool bFixLegs)
{
    local float mult;
    local int adjustedHealAmount, aha2, tempaha;
    local int origHealAmount;
    local float dividedHealAmount;

    if (bUseMedicineSkill)
        adjustedHealAmount = CalculateSkillHealAmount(baseHealPoints);
    else
        adjustedHealAmount = baseHealPoints;

    origHealAmount = adjustedHealAmount;

    if (adjustedHealAmount > 0)
    {
        if (bUseMedicineSkill)
            PlaySound(sound'MedicalHiss', SLOT_None,,, 256);

        // Heal by 3 regions via multiplayer game
        if (( Level.NetMode == NM_DedicatedServer ) || ( Level.NetMode == NM_ListenServer ))
        {
         // DEUS_EX AMSD If legs broken, heal them a little bit first
         if (HealthLegLeft == 0)
         {
            aha2 = adjustedHealAmount;
            if (aha2 >= 5)
               aha2 = 5;
            tempaha = aha2;
            adjustedHealAmount = adjustedHealAmount - aha2;
            HealPart(HealthLegLeft, aha2);
            HealPart(HealthLegRight,tempaha);
                mpMsgServerFlags = mpMsgServerFlags & (~MPSERVERFLAG_LostLegs);
         }
            HealPart(HealthHead, adjustedHealAmount);

            if ( adjustedHealAmount > 0 )
            {
                aha2 = adjustedHealAmount;
                HealPart(HealthTorso, aha2);
                aha2 = adjustedHealAmount;
                HealPart(HealthArmRight,aha2);
                HealPart(HealthArmLeft, adjustedHealAmount);
            }
            if ( adjustedHealAmount > 0 )
            {
                aha2 = adjustedHealAmount;
                HealPart(HealthLegRight, aha2);
                HealPart(HealthLegLeft, adjustedHealAmount);
            }
        }
        else
        {
            if( bUseMedicineSkill || bFixLegs ) {
                HealBrokenPart(HealthLegRight, adjustedHealAmount);
                HealBrokenPart(HealthLegLeft, adjustedHealAmount);
            }
            HealPart(HealthHead, adjustedHealAmount);
            HealPart(HealthTorso, adjustedHealAmount);
            HealPart(HealthLegRight, adjustedHealAmount);
            HealPart(HealthLegLeft, adjustedHealAmount);
            HealPart(HealthArmRight, adjustedHealAmount);
            HealPart(HealthArmLeft, adjustedHealAmount);
        }

        GenerateTotalHealth();

        adjustedHealAmount = origHealAmount - adjustedHealAmount;
    }

    return adjustedHealAmount;
}

function HealBrokenPart(out int points, out int amt)
{
    local int heal;
    heal = 1;
    if( points > 0 || amt < heal ) return;
    amt -= heal;
    HealPart(points, heal);
}

function HealPart(out int points, out int amt)
{
    local int spill;

    points += amt;
    spill = points - default.HealthTorso;
    if (spill > 0)
        points = default.HealthTorso;
    else
        spill = 0;

    amt = spill;
}

exec function ActivateAugmentation(int num)
{
    local Augmentation anAug;
    local int count, wantedSlot, slotIndex;
    local bool bFound;

    if (RestrictInput())
        return;

    anAug = AugmentationSystem.GetAugByKey(num);
    if (Energy == 0 && anAug.GetEnergyRate() > 0)
    {
        ClientMessage(EnergyDepleted);
        PlaySound(AugmentationSystem.FirstAug.DeactivateSound, SLOT_None);
        return;
    }

    if (AugmentationSystem != None)
        AugmentationSystem.ActivateAugByKey(num);
}
