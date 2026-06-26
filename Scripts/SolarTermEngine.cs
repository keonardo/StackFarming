using Godot;
using System;
using System.Collections.Generic;

namespace StackFarming
{
    public enum SolarTerm
    {
        None,
        Jingzhe,     // 惊蛰 (Pests spawn)
        Mangzhong,    // 芒种 (Drought, dry out non-deep water ponds)
        Shuangjiang   // 霜降 (Crop growth rate +100%, tropical creature health decay if exposed)
    }

    public partial class SolarTermEngine : Node
    {
        public static SolarTermEngine Instance { get; private set; }

        public static SolarTerm CurrentTerm { get; private set; } = SolarTerm.None;
        public static float CropGrowthSpeedModifier { get; private set; } = 1.0f;

        [Export] public float TermDuration { get; set; } = 120.0f; // 节气持续时间，默认120秒

        [Signal]
        public delegate void TermChangedEventHandler(string termName);

        private float _termTimer = 0f;
        private int _termIndex = 0;
        private readonly SolarTerm[] _termCycle = new SolarTerm[] 
        { 
            SolarTerm.None, 
            SolarTerm.Jingzhe, 
            SolarTerm.Mangzhong, 
            SolarTerm.Shuangjiang 
        };

        public override void _EnterTree()
        {
            Instance = this;
        }

        public override void _ExitTree()
        {
            if (Instance == this)
            {
                Instance = null;
            }
        }

        public override void _Ready()
        {
            CurrentTerm = SolarTerm.None;
            CropGrowthSpeedModifier = 1.0f;
            _termTimer = 0f;
        }

        public override void _Process(double delta)
        {
            _termTimer += (float)delta;
            if (_termTimer >= TermDuration)
            {
                _termTimer = 0f;
                RotateSolarTerm();
            }

            // 霜降持续性事件：暴露在外的热带生物健康值下降
            if (CurrentTerm == SolarTerm.Shuangjiang)
            {
                ProcessShuangjiangFrostDamage((float)delta);
            }
        }

        private void RotateSolarTerm()
        {
            _termIndex = (_termIndex + 1) % _termCycle.Length;
            SolarTerm oldTerm = CurrentTerm;
            CurrentTerm = _termCycle[_termIndex];

            string termName = CurrentTerm.ToString();
            EmitSignal(SignalName.TermChanged, termName);
            GD.Print($"[Solar Term Engine] Term changed to: {termName}");

            // 退出旧节气清理
            if (oldTerm == SolarTerm.Shuangjiang)
            {
                CropGrowthSpeedModifier = 1.0f;
            }

            // 进入新节气触发
            TriggerTermEvents(CurrentTerm);
        }

        private void TriggerTermEvents(SolarTerm term)
        {
            switch (term)
            {
                case SolarTerm.Jingzhe:
                    // 惊蛰：在所有 [水稻田] 卡牌范围内实例化 3-5 张 [害虫卡]
                    TriggerJingzheEvents();
                    break;
                case SolarTerm.Mangzhong:
                    // 芒种：模拟大旱，瞬间关闭现有非 [深水鱼凼] 滋润状态
                    TriggerMangzhongEvents();
                    break;
                case SolarTerm.Shuangjiang:
                    // 霜降：作物进度 ValueB 增长率提升 100%
                    CropGrowthSpeedModifier = 2.0f;
                    GD.Print("[Solar Term Engine] Shuangjiang active: Crop growth rate +100%");
                    break;
            }
        }

        private void TriggerJingzheEvents()
        {
            GD.Print("[Solar Term Engine] Jingzhe active: Spawning pests on all Rice Fields!");
            List<ContainerCard> farmlands = new List<ContainerCard>();
            FindFarmlands(GetTree().Root, farmlands);

            foreach (var farmland in farmlands)
            {
                if (farmland.CardName.Contains("水稻田") || farmland.CardName.Contains("Rice Field"))
                {
                    int pestCount = GD.RandRange(3, 5);
                    for (int i = 0; i < pestCount; i++)
                    {
                        Vector2 offset = new Vector2((float)GD.RandRange(-20, 20), (float)GD.RandRange(-20, 20));
                        CardSpawner.Instance?.SpawnPestCard(farmland.GlobalPosition + offset);
                    }
                    GD.Print($"[Jingzhe Event] Spawned {pestCount} pests on {farmland.CardName}");
                }
            }
        }

        private void TriggerMangzhongEvents()
        {
            GD.Print("[Solar Term Engine] Mangzhong active: Drought! Disabling non-DeepWaterFishPond irrigation.");
            List<ContainerCard> containers = new List<ContainerCard>();
            FindContainers(GetTree().Root, containers);

            foreach (var container in containers)
            {
                if (container.Type != CardType.DeepWaterFishPond)
                {
                    container.IsIrrigated = false;
                }
            }
            
            // 触发水利链路重检以更新连接状态
            IrrigationManager.Instance?.CheckIrrigationLinkage();
        }

        private void ProcessShuangjiangFrostDamage(float delta)
        {
            // 寻找暴露在外的热带生物并扣减健康值
            List<CreatureCard> creatures = new List<CreatureCard>();
            FindCreatures(GetTree().Root, creatures);

            foreach (var creature in creatures)
            {
                // 判断是否是热带生物且暴露在外
                // 暴露在外：没有放在任何容器上，即 GetContainer() == null
                if (creature.CardName.Contains("热带") || creature.CardName.ToLower().Contains("tropical"))
                {
                    if (creature.GetContainer() == null)
                    {
                        GD.Print($"[Frost Damage] Exposed tropical creature {creature.CardName} is losing health to frost!");
                        creature.Health -= 10f * delta; // 每秒扣减10点健康值
                    }
                }
            }
        }

        #region 场景树查找辅助函数

        private void FindFarmlands(Node node, List<ContainerCard> farmlands)
        {
            if (node is ContainerCard farmland && farmland.Type == CardType.Farmland && GodotObject.IsInstanceValid(farmland))
            {
                farmlands.Add(farmland);
            }

            for (int i = 0; i < node.GetChildCount(); i++)
            {
                FindFarmlands(node.GetChild(i), farmlands);
            }
        }

        private void FindContainers(Node node, List<ContainerCard> containers)
        {
            if (node is ContainerCard container && GodotObject.IsInstanceValid(container))
            {
                containers.Add(container);
            }

            for (int i = 0; i < node.GetChildCount(); i++)
            {
                FindContainers(node.GetChild(i), containers);
            }
        }

        private void FindCreatures(Node node, List<CreatureCard> creatures)
        {
            if (node is CreatureCard creature && GodotObject.IsInstanceValid(creature))
            {
                creatures.Add(creature);
            }

            for (int i = 0; i < node.GetChildCount(); i++)
            {
                FindCreatures(node.GetChild(i), creatures);
            }
        }

        #endregion
    }
}
