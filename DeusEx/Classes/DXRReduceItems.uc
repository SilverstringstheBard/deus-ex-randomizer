class DXRReduceItems extends DXRActorsBase;

function FirstEntry()
{
    Super.FirstEntry();

    ReduceAmmo( float(dxr.flags.ammo)/100.0 );
    ReduceSpawns('Multitool', dxr.flags.multitools);
    ReduceSpawns('Lockpick', dxr.flags.lockpicks);
    ReduceSpawns('BioelectricCell', dxr.flags.biocells);
    ReduceSpawns('MedKit', dxr.flags.medkits);
}

function ReduceAmmo(float mult)
{
    local Weapon w;
    local Ammo a;

    l("ReduceAmmo "$mult);
    SetSeed( "ReduceAmmo" );

    if( mult ~= 1 ) return;

    foreach AllActors(class'Weapon', w)
    {
        if( w.PickupAmmoCount > 0 )
            w.PickupAmmoCount = Clamp(float(w.PickupAmmoCount) * mult, 0, 99999);
    }

    foreach AllActors(class'Ammo', a)
    {
        if( a.AmmoAmount > 0 && ( ! CarriedItem(a) ) )
            a.AmmoAmount = Clamp(float(a.AmmoAmount) * mult, 0, 99999);
    }

    ReduceSpawnsInContainers('Ammo', int(mult*100.0) );
}

function ReduceSpawns(name classname, int percent)
{
    local Actor a;

    if( percent >= 100 ) return;

    SetSeed( "ReduceSpawns " $ classname );

    foreach AllActors(class'Actor', a)
    {
        //if( SkipActor(a, classname) ) continue;
        if( a == dxr.Player ) continue;
        if( a.Owner == dxr.Player ) continue;
        if( ! a.IsA(classname) ) continue;

        if( rng(100) >= percent )
        {
	        DestroyActor( a );
        }
    }

    ReduceSpawnsInContainers(classname, percent);
}

function ReduceSpawnsInContainers(name classname, int percent)
{
    local Containers d;

    if( percent >= 100 ) return;

    SetSeed( "ReduceSpawnsInContainers " $ classname );

    foreach AllActors(class'Containers', d)
    {
        //l("found Decoration " $ d.Name $ " with Contents: " $ d.Contents $ ", looking for " $ classname);
        if( rng(100) >= percent ) {
            if( ClassIsA( d.Contents, classname) ) d.Contents = d.Content2;
            if( ClassIsA( d.Contents, classname) ) d.Content2 = d.Content3;
            if( ClassIsA( d.Contents, classname) ) d.Content3 = None;
        }
    }
}
