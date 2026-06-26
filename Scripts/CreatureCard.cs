using Godot;
using System;
using System.Collections.Generic;

namespace StackFarming
{
    public partial class CreatureCard : BaseCard
    {
        [Export] public float MetabolismRate { get; set; } = 10f; // 每秒进度增加值 (for animals)
        [Export] public float BaseCropGrowthRate { get; set; } = 5f; // 作物基础生长速度 (percent/s)
        [Export] public float FecesMultiplier { get; set; } = 1.5f; // 粪便强度的乘数
        [Export] public float OverCapacityCropDamage { get; set; } = 8f; // 超载时每秒扣减作物的健康值
        [Export] public float PreyCheckInterval { get; set; } = 1.0f; // 捕食/超载检测间隔

        [Signal]
        public delegate void OnPestDetectedEventHandler(CreatureCard predator, PestCard prey);

        private float _interactionTimer = 0f;

        public override void _Ready()
        {
            base._Ready();
            // 确保角色是生物
            Role = CardRole.Creature;
            if (Health <= 0f)
            {
                Health = 100f; // 默认健康值
            }
        }

        public override void _Process(double delta)
        {
            base._Process(delta);

            if (Type == CardType.Animal)
            {
                ProcessAnimalMetabolism((float)delta);
                ProcessAnimalInteractions((float)delta);
            }
            else if (Type == CardType.Crop)
            {
                ProcessCropGrowth((float)delta);
            }
        }

        /// <summary>
        /// 动物代谢逻辑：ValueB (Progress) 满时，在当前坐标生成一张 [粪便卡]
        /// </summary>
        private void ProcessAnimalMetabolism(float delta)
        {
            Progress += MetabolismRate * delta;

            if (Progress >= 100f)
            {
                Progress = 0f;
                SpawnFeces();
            }
        }

        /// <summary>
        /// 周期性执行捕食与背叛机制
        /// </summary>
        private void ProcessAnimalInteractions(float delta)
        {
            _interactionTimer += delta;
            if (_interactionTimer >= PreyCheckInterval)
            {
                _interactionTimer = 0f;

                ContainerCard container = GetContainer();
                if (container == null) return;

                // 1. 检测容器内的害虫卡 (主动捕食)
                PestCard pest = FindPestInContainer(container);
                if (pest != null && GodotObject.IsInstanceValid(pest))
                {
                    GD.Print($"[Predation] {CardName} ate a pest {pest.CardName}!");
                    EmitSignal(SignalName.OnPestDetected, this, pest);
                    PlayPredationAnimation(pest.GlobalPosition);

                    pest.QueueFree(); // 销毁害虫卡

                    // 重置自身 ValueB (Progress) 并由于进食加速瞬间产一次粪
                    Progress = 0f;
                    SpawnFeces();
                    PlayProduceAnimation();
                    return; // 捕食成功后，本轮不执行背叛扣血
                }

                // 2. 背叛机制: 若无害虫且动物数量超过容器承载力
                int animalCount = container.GetAnimalCount();
                if (animalCount > container.Capacity)
                {
                    GD.Print($"[Betrayal] Overcapacity! Animals ({animalCount}/{container.Capacity}) damage crops in {container.CardName}.");
                    container.ApplyAnimalBetrayalDamage(OverCapacityCropDamage * PreyCheckInterval);
                }
            }
        }

        /// <summary>
        /// 作物生长逻辑：当 [粪便卡] 堆叠在作物上时，利用 ValueA (Intensity) 线性提升作物的 ValueB (Progress) 生长速度
        /// </summary>
        private void ProcessCropGrowth(float delta)
        {
            // 检查是否有粪便卡堆叠在自己上面
            float fecesIntensity = 0f;
            BaseCard child = StackChild;
            
            // 沿堆叠链向上寻找堆叠在该作物上的粪便卡
            while (child != null)
            {
                if (child.Type == CardType.Feces)
                {
                    fecesIntensity += child.ValueA; // 累加粪便卡的 Intensity
                }
                child = child.StackChild;
            }

            // 线性提升生长速度
            float currentGrowthRate = BaseCropGrowthRate + fecesIntensity * FecesMultiplier;
            
            // 节气引擎可能会影响生长速率 (由 SolarTermEngine 全局属性调节，我们使用一个全局倍率)
            currentGrowthRate *= SolarTermEngine.CropGrowthSpeedModifier;

            Progress += currentGrowthRate * delta;

            if (Progress >= 100f)
            {
                // 生长成熟，重置进度并生成产出 (e.g. 稻谷)
                Progress = 0f;
                GD.Print($"[Crop] {CardName} matured! Harvested grain.");
                CardSpawner.Instance?.SpawnResourceCard(CardType.DryGrass, "稻谷", GlobalPosition + new Vector2(20, 20));
            }
        }

        private void SpawnFeces()
        {
            GD.Print($"[Metabolism] {CardName} generated feces!");
            PlayProduceAnimation();
            Vector2 offset = new Vector2((float)GD.RandRange(-15, 15), (float)GD.RandRange(-15, 15));
            CardSpawner.Instance?.SpawnResourceCard(CardType.Feces, "粪便卡", GlobalPosition + offset);
        }

        private PestCard FindPestInContainer(ContainerCard container)
        {
            // 获取所有和容器物理重叠的害虫
            foreach (Area2D area in container.GetOverlappingAreas())
            {
                if (area is PestCard pest && GodotObject.IsInstanceValid(pest))
                {
                    return pest;
                }
            }
            return null;
        }
    }
}
