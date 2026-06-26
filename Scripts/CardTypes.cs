namespace StackFarming
{
    public enum CardRole
    {
        Creature,  // 生物卡: ValueA=Health, ValueB=Progress
        Resource,  // 资源卡: ValueA=Intensity, ValueB=Duration
        Container  // 容器卡: ValueA=Capacity, ValueB=Moisture
    }

    public enum CardType
    {
        // Creatures
        Animal,           // 动物卡 (e.g., 小鸭子)
        Crop,             // 作物卡 (e.g., 水稻)
        Fish,             // 鱼类卡 (水生生物)
        
        // Resources
        Feces,            // 粪便卡
        DeadFish,         // 死鱼
        DryGrass,         // 枯草
        Pest,             // 害虫卡 (不参与堆叠，附着在作物上)
        
        // Containers
        Farmland,         // 农田 / 水稻田
        DeepWaterFishPond,// 深水鱼凼
        River,            // 河道 (水源)
        Canal             // 水渠 (水利连接器)
    }
}
